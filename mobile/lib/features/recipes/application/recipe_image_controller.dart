import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recipe_image_repository.dart';

/// Identifies a recipe for image lookups — [clientId] namespaces the local
/// cache/ETag, [serverId] is what the REST call needs. [imageUpdatedAt] is
/// part of the key (not just metadata) so that a photo change picked up from
/// *another* device via a delta pull — which updates this timestamp on the
/// local recipe row but has no way to call [RecipeImageController]'s explicit
/// invalidate — still gets a fresh provider instance instead of reusing a
/// never-invalidated one that would otherwise cache stale bytes forever.
typedef RecipeImageKey = ({String clientId, int serverId, DateTime? imageUpdatedAt});

/// The recipe's thumbnail bytes, or null if it has no photo set. Callers
/// also re-fetch by invalidating this provider (done by [RecipeImageController]
/// after a successful upload/remove, for the same-device case where the local
/// imageUpdatedAt hasn't caught up yet) rather than the provider holding
/// mutable state itself. autoDispose: the on-disk ETag cache in
/// RecipeImageRepository is what persists across app sessions — no need to
/// also keep every viewed recipe's thumbnail bytes in memory indefinitely.
final recipeThumbnailProvider =
    FutureProvider.autoDispose.family<Uint8List?, RecipeImageKey>((ref, key) {
  return ref.watch(recipeImageRepositoryProvider).fetchThumbnail(key.clientId, key.serverId);
});

/// Upload/remove a recipe's photo. Online-only, same as the profile picture
/// flow — errors propagate to the caller so the edit screen can show its
/// usual error snackbar.
class RecipeImageController {
  RecipeImageController(this._ref);

  final Ref _ref;

  RecipeImageRepository get _repo => _ref.read(recipeImageRepositoryProvider);

  Future<void> upload(RecipeImageKey key, File imageFile) async {
    await _repo.upload(key.clientId, key.serverId, imageFile);
    _ref.invalidate(recipeThumbnailProvider(key));
  }

  Future<void> remove(RecipeImageKey key) async {
    await _repo.delete(key.clientId, key.serverId);
    _ref.invalidate(recipeThumbnailProvider(key));
  }
}

final recipeImageControllerProvider =
    Provider<RecipeImageController>((ref) => RecipeImageController(ref));
