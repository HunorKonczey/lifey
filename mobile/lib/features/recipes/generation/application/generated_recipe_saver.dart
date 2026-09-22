import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../nutrition/application/food_controller.dart';
import '../../../nutrition/data/food_repository.dart';
import '../../application/recipes_controller.dart';
import '../../data/recipe_repository.dart';
import '../domain/generated_recipe.dart';

/// What saving a proposal produced: the new recipe's local id, and how many
/// ingredients had to be left out.
typedef SavedRecipe = ({String clientId, int skippedIngredients});

/// Turns a [GeneratedRecipe] into a real, local-first recipe
/// (docs/23-ai-calorie-estimation-plan.md Phase 2): new foods are created in
/// the user's catalog first, existing ones are resolved from the server id the
/// backend referenced, and then the recipe is written like any other.
///
/// Nothing here is online: the generation was the only network step. Both
/// writes go through the normal repositories, so they sync through the outbox.
class GeneratedRecipeSaver {
  GeneratedRecipeSaver(this._ref);

  final Ref _ref;

  /// [quantities] overrides the proposal's grams per ingredient index, for
  /// what the user edited in the preview; an ingredient missing from it keeps
  /// the proposed amount, and a null value drops it.
  Future<SavedRecipe> save(
    GeneratedRecipe recipe, {
    required String name,
    required int servings,
    Map<int, double?> quantities = const {},
  }) async {
    final foods = _ref.read(foodControllerProvider.notifier);
    final foodRepository = _ref.read(foodRepositoryProvider);

    final ingredients = <RecipeIngredientInput>[];
    int skipped = 0;
    for (var index = 0; index < recipe.ingredients.length; index++) {
      final ingredient = recipe.ingredients[index];
      final grams = quantities.containsKey(index)
          ? quantities[index]
          : ingredient.quantityInGrams;
      if (grams == null || grams <= 0) continue;

      final newFood = ingredient.newFood;
      final String clientId;
      if (newFood != null) {
        final created = await foods.addFood(
          name: newFood.name,
          calories: newFood.caloriesPer100g,
          protein: newFood.proteinPer100g,
          carbs: newFood.carbsPer100g,
          fat: newFood.fatPer100g,
        );
        clientId = created.clientId;
      } else {
        // The backend only references foods this user owns, so a miss means
        // the row hasn't been pulled down yet. Rare, and not worth failing the
        // whole save over — the ingredient is left out and reported.
        final existing = await foodRepository.findByServerId(ingredient.existingFoodId!);
        if (existing == null) {
          skipped++;
          continue;
        }
        clientId = existing.clientId;
      }
      ingredients.add(RecipeIngredientInput(foodClientId: clientId, grams: grams));
    }

    if (ingredients.isEmpty) {
      // A recipe without ingredients is rejected by the backend and useless
      // locally; better to fail the save than to write one that never syncs.
      throw StateError('No ingredient survived the preview edits');
    }
    final clientId = await _ref.read(recipeControllerProvider.notifier).createRecipe(
          name: name,
          description: recipe.description,
          servings: servings,
          ingredients: ingredients,
        );
    return (clientId: clientId, skippedIngredients: skipped);
  }
}

final generatedRecipeSaverProvider = Provider<GeneratedRecipeSaver>(GeneratedRecipeSaver.new);
