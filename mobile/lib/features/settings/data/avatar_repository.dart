import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/dio_client.dart';

/// REST + on-disk cache access to the current user's profile picture
/// (`/users/me/avatar`). Online-only (docs/22-profile-picture-plan.md) — not
/// routed through the offline outbox, since a single small binary blob per
/// user isn't worth the sync/conflict machinery there. The on-disk cache
/// (keyed by the server's ETag) is what keeps the picture visible offline.
class AvatarRepository {
  AvatarRepository(this._dio);

  final Dio _dio;

  static const _etagPrefsKey = 'avatar_etag';
  static const _fileName = 'avatar.jpg';

  Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Returns the current avatar bytes (served from cache on a 304, or when
  /// the request fails outright while a cached copy exists), or null if the
  /// user has no avatar set.
  Future<Uint8List?> fetch() async {
    final prefs = await SharedPreferences.getInstance();
    final etag = prefs.getString(_etagPrefsKey);
    final file = await _cacheFile();

    try {
      final response = await _dio.get<List<int>>(
        '/users/me/avatar',
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
        await _clearLocal(prefs, file);
        return null;
      }

      final bytes = Uint8List.fromList(response.data!);
      await file.writeAsBytes(bytes, flush: true);
      final newEtag = response.headers.value('etag');
      if (newEtag != null) {
        await prefs.setString(_etagPrefsKey, newEtag);
      }
      return bytes;
    } on DioException catch (e) {
      // A read is allowed to be stale: fall back to whatever's cached rather
      // than surfacing a transport error just for showing the avatar.
      if (file.existsSync()) return file.readAsBytes();
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.unknown) {
        return null;
      }
      rethrow;
    }
  }

  /// Uploads [imageFile], then re-fetches so the caller gets back the
  /// server's re-encoded (cropped/resized) version rather than the raw pick.
  Future<Uint8List?> upload(File imageFile) async {
    await _dio.put<void>(
      '/users/me/avatar',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(imageFile.path),
      }),
    );
    return fetch();
  }

  Future<void> delete() async {
    await _dio.delete<void>('/users/me/avatar');
    final prefs = await SharedPreferences.getInstance();
    await _clearLocal(prefs, await _cacheFile());
  }

  /// Drops the local cache without touching the server — called on logout so
  /// a different account signing in on this device doesn't briefly flash the
  /// previous account's cached picture.
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearLocal(prefs, await _cacheFile());
  }

  Future<void> _clearLocal(SharedPreferences prefs, File file) async {
    await prefs.remove(_etagPrefsKey);
    if (file.existsSync()) await file.delete();
  }
}

final avatarRepositoryProvider = Provider<AvatarRepository>((ref) {
  return AvatarRepository(ref.watch(dioClientProvider));
});
