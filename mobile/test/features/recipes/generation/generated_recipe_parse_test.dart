import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/recipes/generation/domain/generated_recipe.dart';

/// LIF-150: what `POST /recipes/generate` sends for fibre and sugars - and an older server that sends none.
void main() {
  Map<String, dynamic> json({Map<String, dynamic>? perServingExtra, Map<String, dynamic>? foodExtra}) => {
        'name': 'Oat bowl',
        'description': '1. Mix.',
        'servings': 2,
        'ingredients': [
          {
            'name': 'Oats',
            'quantityInGrams': 100,
            'existingFoodId': null,
            'newFood': {
              'name': 'Oats',
              'caloriesPer100g': 370,
              'proteinPer100g': 13,
              'carbsPer100g': 60,
              'fatPer100g': 7,
              ...?foodExtra,
            },
          },
        ],
        'perServing': {'calories': 185, 'proteinGrams': 6.5, 'carbsGrams': 30, 'fatGrams': 3.5, ...?perServingExtra},
      };

  test('reads the fibre and sugar estimate of a new food and the per-serving totals', () {
    final recipe = GeneratedRecipe.fromJson(json(
      foodExtra: {'fiberPer100g': 10, 'sugarPer100g': 1.5},
      perServingExtra: {'fiberGrams': 5.0, 'sugarGrams': 0.75, 'fiberSugarPartial': true},
    ));

    expect(recipe.ingredients.single.newFood!.fiberPer100g, 10);
    expect(recipe.ingredients.single.newFood!.sugarPer100g, 1.5);
    expect(recipe.perServing.fiber, 5);
    expect(recipe.perServing.sugar, 0.75);
    expect(recipe.perServing.fiberSugarPartial, isTrue);
    expect(recipe.perServing.fiberSugar.partial, isTrue);
    expect(recipe.perServing.fiberSugar.isEmpty, isFalse);
  });

  test('a server that sends none leaves them unknown (null), not 0', () {
    final recipe = GeneratedRecipe.fromJson(json());

    expect(recipe.ingredients.single.newFood!.fiberPer100g, isNull);
    expect(recipe.ingredients.single.newFood!.sugarPer100g, isNull);
    expect(recipe.perServing.fiber, isNull);
    expect(recipe.perServing.sugar, isNull);
    expect(recipe.perServing.fiberSugarPartial, isFalse);
    expect(recipe.perServing.fiberSugar.isEmpty, isTrue);
  });

  test('explicit nulls from the server (no ingredient had a figure) read as unknown too', () {
    final recipe = GeneratedRecipe.fromJson(json(perServingExtra: {'fiberGrams': null, 'sugarGrams': null, 'fiberSugarPartial': false}));

    expect(recipe.perServing.fiberSugar.isEmpty, isTrue);
  });
}
