import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recipe_image_repository.dart';
import '../data/recipe_repository.dart';

/// Identifies a recipe for image lookups — [clientId] namespaces the local
/// cache/ETag, [serverId] is what the REST call needs. [imageUpdatedAt] is
/// part of the key (not just metadata) so that any photo change — from this
/// device (see [RecipeImageController]) or picked up from another device via
/// a delta pull — always produces a fresh provider instance instead of
/// reusing a never-invalidated one that would otherwise cache stale bytes
/// (or a stale "no photo" result) forever.
typedef RecipeImageKey = ({String clientId, int serverId, DateTime? imageUpdatedAt});

/// The recipe's thumbnail bytes, or null if it has no photo set. autoDispose:
/// the on-disk ETag cache in RecipeImageRepository is what persists across
/// app sessions — no need to also keep every viewed recipe's thumbnail bytes
/// in memory indefinitely.
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
  RecipeRepository get _recipeRepo => _ref.read(recipeRepositoryProvider);

  /// Mirrors the change onto the local recipe row immediately after the REST
  /// call succeeds — this endpoint isn't covered by the delta-sync pull, so
  /// without it the UI (gated on the recipe's local `imageUpdatedAt`) would
  /// keep showing "no photo"/the stale photo until the next background sync.
  /// [recipeThumbnailProvider] doesn't need an explicit invalidate for this:
  /// the local write flows through the recipe's watch stream, which changes
  /// [RecipeImageKey.imageUpdatedAt] and so naturally produces a fresh key.
  Future<void> upload(RecipeImageKey key, File imageFile) async {
    await _repo.upload(key.clientId, key.serverId, imageFile);
    await _recipeRepo.setImageUpdatedAt(key.clientId, DateTime.now());
  }

  Future<void> remove(RecipeImageKey key) async {
    await _repo.delete(key.clientId, key.serverId);
    await _recipeRepo.setImageUpdatedAt(key.clientId, null);
  }
}

final recipeImageControllerProvider =
    Provider<RecipeImageController>((ref) => RecipeImageController(ref));
