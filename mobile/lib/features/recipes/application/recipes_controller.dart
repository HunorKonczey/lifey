import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recipe_repository.dart';
import '../domain/recipe.dart';

/// Loads and mutates the list of recipes.
class RecipeController extends AsyncNotifier<List<Recipe>> {
  RecipeRepository get _repo => ref.read(recipeRepositoryProvider);

  @override
  Future<List<Recipe>> build() => _repo.fetchAll();

  Future<void> createRecipe({
    required String name,
    String? description,
    required List<RecipeIngredientInput> ingredients,
  }) async {
    await _repo.create(
      name: name,
      description: description,
      ingredients: ingredients,
    );
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> updateRecipe(
    int id, {
    required String name,
    String? description,
    required List<RecipeIngredientInput> ingredients,
  }) async {
    await _repo.update(
      id,
      name: name,
      description: description,
      ingredients: ingredients,
    );
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> deleteRecipe(int id) async {
    await _repo.delete(id);
    state = await AsyncValue.guard(_repo.fetchAll);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.fetchAll);
  }
}

final recipeControllerProvider =
    AsyncNotifierProvider<RecipeController, List<Recipe>>(RecipeController.new);
