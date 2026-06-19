import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    required List<RecipeIngredientInput> ingredients,
  }) {
    return _repo.create(name: name, description: description, ingredients: ingredients);
  }

  Future<void> updateRecipe(
    String clientId, {
    required String name,
    String? description,
    required List<RecipeIngredientInput> ingredients,
  }) {
    return _repo.update(clientId, name: name, description: description, ingredients: ingredients);
  }

  Future<void> deleteRecipe(String clientId) => _repo.delete(clientId);

  Future<void> refresh() => ref.read(syncEngineProvider).sync();
}

final recipeControllerProvider =
    StreamNotifierProvider<RecipeController, List<Recipe>>(RecipeController.new);
