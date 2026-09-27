import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/recipes/domain/recipe.dart';
import 'package:lifey/features/recipes/domain/recipe_filter.dart';

Recipe _recipe({required double kcal, required double protein, int servings = 1, bool favorite = false}) => Recipe(
      clientId: 'r',
      name: 'Recipe',
      favorite: favorite,
      servings: servings,
      ingredients: [
        RecipeIngredient(
          foodClientId: 'f',
          foodName: 'Food',
          quantityInGrams: 100,
          calories: kcal,
          protein: protein,
          carbs: 0,
          fat: 0,
        ),
      ],
    );

void main() {
  group('All / Favourites', () {
    test('all keeps everything', () {
      expect(matchesRecipeFilter(_recipe(kcal: 500, protein: 10), RecipeFilter.all), isTrue);
    });

    test('favourites keeps only starred recipes', () {
      expect(matchesRecipeFilter(_recipe(kcal: 500, protein: 10, favorite: true), RecipeFilter.favourites), isTrue);
      expect(matchesRecipeFilter(_recipe(kcal: 500, protein: 10), RecipeFilter.favourites), isFalse);
    });
  });

  group('High protein: protein kcal ≥ 30 % of the recipe kcal', () {
    test('the canvas chicken bowl (46 g in 520 kcal = 35 %) qualifies', () {
      expect(matchesRecipeFilter(_recipe(kcal: 520, protein: 46), RecipeFilter.highProtein), isTrue);
    });

    test('exactly 30 % qualifies, just under does not', () {
      expect(matchesRecipeFilter(_recipe(kcal: 400, protein: 30), RecipeFilter.highProtein), isTrue); // 120 / 400
      expect(matchesRecipeFilter(_recipe(kcal: 400, protein: 29), RecipeFilter.highProtein), isFalse);
    });

    test('the share is independent of the number of servings', () {
      expect(matchesRecipeFilter(_recipe(kcal: 1040, protein: 92, servings: 2), RecipeFilter.highProtein), isTrue);
    });

    test('a recipe without calories is not high protein', () {
      expect(matchesRecipeFilter(_recipe(kcal: 0, protein: 0), RecipeFilter.highProtein), isFalse);
    });
  });

  group('< 400 kcal per serving', () {
    test('a single-serving recipe under the limit', () {
      expect(matchesRecipeFilter(_recipe(kcal: 383, protein: 23), RecipeFilter.lowCalorie), isTrue);
      expect(matchesRecipeFilter(_recipe(kcal: 400, protein: 23), RecipeFilter.lowCalorie), isFalse);
    });

    test('uses the serving, not the whole pot', () {
      expect(matchesRecipeFilter(_recipe(kcal: 1200, protein: 60, servings: 4), RecipeFilter.lowCalorie), isTrue);
      expect(matchesRecipeFilter(_recipe(kcal: 1200, protein: 60, servings: 2), RecipeFilter.lowCalorie), isFalse);
    });

    test('an empty recipe is not a light meal', () {
      expect(matchesRecipeFilter(_recipe(kcal: 0, protein: 0), RecipeFilter.lowCalorie), isFalse);
    });
  });

  test('per-serving helpers', () {
    final r = _recipe(kcal: 1200, protein: 80, servings: 4);
    expect(caloriesPerServing(r), 300);
    expect(proteinPerServing(r), 20);
  });
}
