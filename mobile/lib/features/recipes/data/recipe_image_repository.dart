import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/dio_client.dart';

/// REST + on-disk cache access to a recipe's photo thumbnail
/// (`/recipes/{recipeServerId}/image/thumbnail`). Mirrors AvatarRepository's
/// pattern (see docs/22-profile-picture-plan.md), keyed per recipe instead of
/// per user: the on-disk cache file and ETag are namespaced by the recipe's
/// `clientId` (stable across a sync, unlike `serverId` which starts null).
///
/// Online-only, same as avatars — not routed through the offline outbox.
/// [recipeServerId] is required for every call: a recipe with no server id
/// yet (never synced) has no photo endpoint to call.
class RecipeImageRepository {
  RecipeImageRepository(this._dio);

  final Dio _dio;

  Future<Directory> _cacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'recipe_images'));
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
    return imagesDir;
  }

  Future<File> _cacheFile(String recipeClientId) async {
    final dir = await _cacheDir();
    return File(p.join(dir.path, '$recipeClientId.jpg'));
  }

  String _etagPrefsKey(String recipeClientId) => 'recipe_image_etag_$recipeClientId';

  /// Returns the recipe's thumbnail bytes (served from cache on a 304, or
  /// when the request fails outright while a cached copy exists), or null if
  /// the recipe has no photo set.
  Future<Uint8List?> fetchThumbnail(String recipeClientId, int recipeServerId) async {
    final prefs = await SharedPreferences.getInstance();
    final etagKey = _etagPrefsKey(recipeClientId);
    final etag = prefs.getString(etagKey);
    final file = await _cacheFile(recipeClientId);

    try {
      final response = await _dio.get<List<int>>(
        '/recipes/$recipeServerId/image/thumbnail',
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
        await _clearLocal(prefs, etagKey, file);
        return null;
      }

      final bytes = Uint8List.fromList(response.data!);
      await file.writeAsBytes(bytes, flush: true);
      final newEtag = response.headers.value('etag');
      if (newEtag != null) {
        await prefs.setString(etagKey, newEtag);
      }
      return bytes;
    } on DioException catch (e) {
      if (file.existsSync()) return file.readAsBytes();
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.unknown) {
        return null;
      }
      rethrow;
    }
  }

  /// Uploads [imageFile] as the recipe's photo.
  Future<void> upload(String recipeClientId, int recipeServerId, File imageFile) async {
    await _dio.put<void>(
      '/recipes/$recipeServerId/image',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(imageFile.path),
      }),
    );
  }

  Future<void> delete(String recipeClientId, int recipeServerId) async {
    await _dio.delete<void>('/recipes/$recipeServerId/image');
    final prefs = await SharedPreferences.getInstance();
    await _clearLocal(prefs, _etagPrefsKey(recipeClientId), await _cacheFile(recipeClientId));
  }

  Future<void> _clearLocal(SharedPreferences prefs, String etagKey, File file) async {
    await prefs.remove(etagKey);
    if (file.existsSync()) await file.delete();
  }

  /// Drops every cached recipe photo without touching the server — called on
  /// logout so a different account signing in on this device doesn't inherit
  /// this account's cached photos (same reasoning as AvatarRepository.clearCache).
  Future<void> clearCache() async {
    final dir = await _cacheDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

final recipeImageRepositoryProvider = Provider<RecipeImageRepository>((ref) {
  return RecipeImageRepository(ref.watch(dioClientProvider));
});
