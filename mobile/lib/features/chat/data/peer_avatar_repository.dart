import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/dio_client.dart';

/// The peer's profile picture, for the avatars the chat draws in every row,
/// thread header and bubble.
///
/// **On [dioClientProvider], not the chat client.** Pictures belong to the
/// monolith's user feature (docs/22-profile-picture-plan.md) and the chat
/// service cannot even read that table — the same split as
/// `TrainerClientsRepository`, which also lives under `features/chat/` while
/// calling the main API.
///
/// Cached on disk per user and revalidated with the ETag, exactly like the
/// own-avatar cache in `features/settings/data/avatar_repository.dart`: an
/// avatar is small, changes almost never, and must still be there when the app
/// opens offline.
class PeerAvatarRepository {
  PeerAvatarRepository(this._dio);

  final Dio _dio;

  static String _etagPrefsKey(int userId) => 'peer_avatar_etag_$userId';

  static String _fileName(int userId) => 'peer_avatar_$userId.jpg';

  Future<File> _cacheFile(int userId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName(userId)));
  }

  /// The peer's picture bytes, or null when there is nothing to show.
  ///
  /// Null covers three cases the caller does not need to tell apart — the peer
  /// never set a picture, the relationship that entitles us to it is gone (both
  /// answer 404), or we are offline with nothing cached. All three render the
  /// monogram.
  Future<Uint8List?> fetch(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final etag = prefs.getString(_etagPrefsKey(userId));
    final file = await _cacheFile(userId);

    try {
      final response = await _dio.get<List<int>>(
        '/users/$userId/avatar',
        options: Options(
          responseType: ResponseType.bytes,
          headers: etag != null ? {'If-None-Match': etag} : null,
          validateStatus: (code) => code == 200 || code == 304 || code == 404,
        ),
      );

      if (response.statusCode == 304) {
        return file.existsSync() ? file.readAsBytes() : null;
      }
      if (response.statusCode == 404) {
        await _clearLocal(prefs, userId, file);
        return null;
      }

      final bytes = Uint8List.fromList(response.data!);
      await file.writeAsBytes(bytes, flush: true);
      final newEtag = response.headers.value('etag');
      if (newEtag != null) {
        await prefs.setString(_etagPrefsKey(userId), newEtag);
      }
      return bytes;
    } on DioException {
      // A picture is never worth an error on screen: fall back to the cached
      // copy, and to the monogram when there isn't one.
      if (file.existsSync()) return file.readAsBytes();
      return null;
    }
  }

  /// Drops every cached peer picture. Called on logout, alongside the other
  /// image caches: these are photographs of the people the previous account
  /// talked to, and whoever signs in next has no business with them.
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith('peer_avatar_etag_')).toList()) {
      await prefs.remove(key);
    }
    final dir = await getApplicationDocumentsDirectory();
    for (final entity in dir.listSync()) {
      if (entity is File && p.basename(entity.path).startsWith('peer_avatar_')) {
        await entity.delete();
      }
    }
  }

  Future<void> _clearLocal(SharedPreferences prefs, int userId, File file) async {
    await prefs.remove(_etagPrefsKey(userId));
    if (file.existsSync()) await file.delete();
  }
}

final peerAvatarRepositoryProvider = Provider<PeerAvatarRepository>((ref) {
  return PeerAvatarRepository(ref.watch(dioClientProvider));
});
