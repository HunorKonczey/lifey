import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../data/recipe_repository.dart';
import '../domain/recipe.dart';

/// Streams recipes from the local cache and exposes the mutations.
class RecipeController extends StreamNotifier<List<Recipe>> {
  RecipeRepository get _repo => ref.read(recipeRepositoryProvider);

  @override
  Stream<List<Recipe>> build() => _repo.watchAll();

  Future<void> createRecipe({
    required String name,
    String? description,
    bool favorite = false,
    required List<RecipeIngredientInput> ingredients,
  }) {
    return _repo.create(
        name: name, description: description, favorite: favorite, ingredients: ingredients);
  }

  Future<void> updateRecipe(
    String clientId, {
    required String name,
    String? description,
    bool favorite = false,
    required List<RecipeIngredientInput> ingredients,
  }) {
    return _repo.update(clientId,
        name: name, description: description, favorite: favorite, ingredients: ingredients);
  }

  Future<void> deleteRecipe(String clientId) => _repo.delete(clientId);

  Future<void> toggleFavorite(String clientId, bool value) =>
      _repo.toggleFavorite(clientId, value);

  /// Drains the outbox, then re-pulls from the server — matching what the
  /// dashboard's pull-to-refresh does. Without the pull half, swiping to
  /// refresh only pushes local edits and never reconciles a stale/corrupted
  /// local row with the server's truth.
  Future<void> refresh() async {
    try {
      await ref.read(syncEngineProvider).sync();
      await ref.read(pullEngineProvider).pullAll();
    } catch (_) {
      // Best-effort: no connectivity or a backend hiccup leaves the cache as-is.
    }
  }
}

final recipeControllerProvider =
    StreamNotifierProvider<RecipeController, List<Recipe>>(RecipeController.new);
