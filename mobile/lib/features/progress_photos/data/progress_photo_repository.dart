import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/dio_client.dart';
import '../domain/progress_photo.dart';

/// REST + on-disk cache access to progress photos (`/progress-photos`,
/// docs/80). Online-only, the same decision as avatars and recipe photos
/// (docs/80 §2.1): not routed through the offline outbox, the server is the
/// source of truth, and thumbnails/full images are cached on disk with an
/// ETag so a viewed photo costs one conditional request, not a download.
///
/// Cache files are keyed by the server id; photos are never replaced in
/// place (an edit changes metadata only), so an id's bytes only ever change
/// by being deleted.
class ProgressPhotoRepository {
  ProgressPhotoRepository(this._dio, {Future<Directory> Function()? cacheRoot})
      : _cacheRoot = cacheRoot ?? getApplicationDocumentsDirectory;

  final Dio _dio;
  final Future<Directory> Function() _cacheRoot;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<ProgressPhoto>> list() async {
    final response = await _dio.get<List<dynamic>>('/progress-photos');
    return [
      for (final json in response.data ?? const <dynamic>[]) ProgressPhoto.fromJson(json as Map<String, dynamic>),
    ];
  }

  Future<ProgressPhoto> upload(
    File file, {
    required DateTime takenOn,
    required PhotoPose pose,
    String? note,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/progress-photos',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'takenOn': _dateFormat.format(takenOn),
        'pose': pose.wire,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );
    return ProgressPhoto.fromJson(response.data!);
  }

  /// Replaces a photo's date, pose and note (a null [note] clears it).
  Future<ProgressPhoto> update(
    int id, {
    required DateTime takenOn,
    required PhotoPose pose,
    String? note,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/progress-photos/$id',
      data: {'takenOn': _dateFormat.format(takenOn), 'pose': pose.wire, 'note': note},
    );
    return ProgressPhoto.fromJson(response.data!);
  }

  Future<void> delete(int id) async {
    await _dio.delete<void>('/progress-photos/$id');
    final prefs = await SharedPreferences.getInstance();
    for (final variant in _Variant.values) {
      await _clearLocal(prefs, await _cacheFile(id, variant), id, variant);
    }
  }

  /// The 256 px thumbnail, or null when there is none and nothing cached.
  Future<Uint8List?> fetchThumbnail(int id) => _fetch(id, _Variant.thumbnail);

  /// The full-size image, or null when there is none and nothing cached.
  Future<Uint8List?> fetchImage(int id) => _fetch(id, _Variant.full);

  Future<Uint8List?> _fetch(int id, _Variant variant) async {
    final prefs = await SharedPreferences.getInstance();
    final file = await _cacheFile(id, variant);
    final etagKey = _etagKey(id, variant);
    final etag = prefs.getString(etagKey);

    try {
      final response = await _dio.get<List<int>>(
        '/progress-photos/$id/${variant.path}',
        options: Options(
          responseType: ResponseType.bytes,
          // Never send a validator for bytes we no longer have: a 304 would then
          // leave us with nothing to show.
          headers: etag != null && file.existsSync() ? {'If-None-Match': etag} : null,
          validateStatus: (code) => code == 200 || code == 304 || code == 404,
        ),
      );

      if (response.statusCode == 304) {
        return file.existsSync() ? await file.readAsBytes() : null;
      }
      if (response.statusCode == 404) {
        await _clearLocal(prefs, file, id, variant);
        return null;
      }

      final bytes = Uint8List.fromList(response.data!);
      await file.writeAsBytes(bytes, flush: true);
      final newEtag = response.headers.value('etag');
      if (newEtag != null) await prefs.setString(etagKey, newEtag);
      return bytes;
    } on DioException catch (e) {
      // Offline (or the server is down): a cached copy is better than nothing.
      if (file.existsSync()) return file.readAsBytes();
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.unknown) {
        return null;
      }
      rethrow;
    }
  }

  Future<Directory> _cacheDir() async {
    final root = await _cacheRoot();
    final dir = Directory(p.join(root.path, 'progress_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _cacheFile(int id, _Variant variant) async =>
      File(p.join((await _cacheDir()).path, '${id}_${variant.path}.jpg'));

  String _etagKey(int id, _Variant variant) => 'progress_photo_etag_${id}_${variant.path}';

  Future<void> _clearLocal(SharedPreferences prefs, File file, int id, _Variant variant) async {
    await prefs.remove(_etagKey(id, variant));
    if (file.existsSync()) await file.delete();
  }

  /// Drops every cached photo without touching the server — called on logout
  /// so a different account signing in on this device never inherits the
  /// previous account's body photos (docs/80 §2.6; same reasoning as
  /// [AvatarRepository.clearCache]). The ETag preferences go too.
  Future<void> clearCache() async {
    final dir = await _cacheDir();
    if (await dir.exists()) await dir.delete(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith('progress_photo_etag_')).toList()) {
      await prefs.remove(key);
    }
  }
}

enum _Variant {
  thumbnail('thumbnail'),
  full('image');

  const _Variant(this.path);

  /// The endpoint suffix, also the cache-file and ETag-key discriminator.
  final String path;
}

final progressPhotoRepositoryProvider = Provider<ProgressPhotoRepository>((ref) {
  return ProgressPhotoRepository(ref.watch(dioClientProvider));
});
