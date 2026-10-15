import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/recipes/domain/recipe.dart';
import 'package:lifey/features/recipes/domain/recipe_portion.dart';

RecipeIngredient _ingredient(
  String name,
  double grams, {
  double calories = 0,
  double protein = 0,
  double carbs = 0,
  double fat = 0,
  double? fiber,
  double? sugar,
}) =>
    RecipeIngredient(
      foodClientId: 'food-$name',
      foodName: name,
      quantityInGrams: grams,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
    );

/// 4 servings: 400 g flour (1400 kcal) + 200 g oil (1800 kcal).
final _recipe = Recipe(
  clientId: 'r1',
  name: 'Bread',
  servings: 4,
  ingredients: [
    _ingredient('flour', 400, calories: 1400, protein: 40, carbs: 300, fat: 4),
    _ingredient('oil', 200, calories: 1800, fat: 200),
  ],
);

void main() {
  group('grams', () {
    test('no divisor is the whole recipe, exactly as stored', () {
      final p = RecipePortion(Recipe(
        clientId: 'r',
        name: 'odd',
        ingredients: [_ingredient('x', 33.337)],
      ));
      expect(p.gramsFor(0), 33.337);
    });

    test('a divisor divides and rounds to two decimals', () {
      final p = RecipePortion(
        Recipe(clientId: 'r', name: 'odd', ingredients: [_ingredient('x', 100)]),
        divisor: 3,
      );
      expect(p.defaultGramsFor(0), 33.33);
    });

    test('a divisor of 1 still rounds (it is an explicit split, not the whole)', () {
      final p = RecipePortion(
        Recipe(clientId: 'r', name: 'odd', ingredients: [_ingredient('x', 33.337)]),
        divisor: 1,
      );
      expect(p.gramsFor(0), 33.34);
    });

    test('a fractional divisor is a number of servings eaten', () {
      // 4 servings, 1.5 eaten: divisor = 4 / 1.5.
      final p = RecipePortion(_recipe, divisor: 4 / 1.5);
      expect(p.gramsFor(0), 150);
      expect(p.gramsFor(1), 75);
    });

    test('an override beats the default and is not rescaled by the divisor', () {
      final p = RecipePortion(_recipe, divisor: 4, overrides: {0: 60});
      expect(p.gramsFor(0), 60);
      expect(p.gramsFor(1), 50);
      final other = RecipePortion(_recipe, divisor: 2, overrides: {0: 60});
      expect(other.gramsFor(0), 60);
      expect(other.gramsFor(1), 100);
    });
  });

  group('macros', () {
    test('scale with the grams logged', () {
      final p = RecipePortion(_recipe, divisor: 4);
      expect(p.calories, closeTo(800, 1e-9));
      expect(p.protein, closeTo(10, 1e-9));
      expect(p.carbs, closeTo(75, 1e-9));
      expect(p.fat, closeTo(51, 1e-9));
    });

    test('use overridden grams', () {
      final p = RecipePortion(_recipe, divisor: 4, overrides: {1: 0});
      expect(p.calories, closeTo(350, 1e-9));
    });

    test('an ingredient with 0 g in the recipe contributes nothing and does not divide by zero', () {
      final p = RecipePortion(Recipe(
        clientId: 'r',
        name: 'zero',
        ingredients: [_ingredient('air', 0, calories: 5), _ingredient('x', 100, calories: 100)],
      ));
      expect(p.calories, 100);
    });

    test('fibre and sugar stay unknown when no ingredient has a figure', () {
      expect(RecipePortion(_recipe).fiberSugar.isEmpty, isTrue);
    });

    test('fibre and sugar are scaled to the grams logged', () {
      final recipe = Recipe(
        clientId: 'r',
        name: 'f',
        ingredients: [_ingredient('oats', 200, fiber: 20, sugar: 4)],
      );
      final totals = RecipePortion(recipe, divisor: 2).fiberSugar;
      expect(totals.isEmpty, isFalse);
      expect(totals.fiber, closeTo(10, 1e-9));
      expect(totals.sugar, closeTo(2, 1e-9));
    });
  });

  group('loggable', () {
    test('lists the ingredients with a non-zero amount, in recipe order', () {
      final p = RecipePortion(_recipe, divisor: 4, overrides: {0: 0});
      expect(p.loggable.map((e) => e.ingredient.foodName), ['oil']);
      expect(p.loggable.single.grams, 50);
      expect(p.hasLoggableEntry, isTrue);
    });

    test('is empty, and not loggable, when every amount is 0', () {
      final p = RecipePortion(_recipe, overrides: {0: 0, 1: 0});
      expect(p.loggable, isEmpty);
      expect(p.hasLoggableEntry, isFalse);
    });
  });
}
