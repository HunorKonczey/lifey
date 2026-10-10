import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/recipes/data/recipe_repository.dart';
import 'package:lifey/features/recipes/domain/recipe.dart';

RecipeIngredient _ingredient({double? fiber, double? sugar}) => RecipeIngredient(
      foodClientId: 'f',
      foodName: 'Food',
      quantityInGrams: 100,
      calories: 100,
      protein: 5,
      carbs: 10,
      fat: 2,
      fiber: fiber,
      sugar: sugar,
    );

/// LIF-150: a recipe's fibre and sugars are the sum of the ingredients that have a figure - not known is not 0.
void main() {
  group('Recipe.fiberSugar', () {
    test('sums the ingredients', () {
      final recipe = Recipe(clientId: 'r', name: 'Bowl', ingredients: [_ingredient(fiber: 5, sugar: 0.5), _ingredient(fiber: 2.4, sugar: 10)]);

      expect(recipe.fiberSugar.fiber, closeTo(7.4, 1e-9));
      expect(recipe.fiberSugar.sugar, closeTo(10.5, 1e-9));
      expect(recipe.fiberSugar.partial, isFalse);
    });

    test('an ingredient without a figure leaves the known sum and makes it partial', () {
      final recipe = Recipe(clientId: 'r', name: 'Bowl', ingredients: [_ingredient(fiber: 5, sugar: 0.5), _ingredient()]);

      expect(recipe.fiberSugar.fiber, 5);
      expect(recipe.fiberSugar.partial, isTrue);
    });

    test('no figure anywhere is empty, not 0', () {
      final recipe = Recipe(clientId: 'r', name: 'Plain', ingredients: [_ingredient()]);

      expect(recipe.fiberSugar.isEmpty, isTrue);
    });
  });

  group('the repository', () {
    late AppDatabase db;
    late RecipeRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = RecipeRepository(db, OutboxWriter(db, SyncEngine(db, Dio())));
    });

    tearDown(() => db.close());

    test('ingredients carry the food\'s fibre and sugar scaled to the grams; a food without them gives null', () async {
      await db.into(db.foods).insert(FoodsCompanion.insert(
          clientId: 'oats', name: 'Oats', caloriesPer100g: 370, proteinPer100g: 13, fiberPer100g: const Value(10), sugarPer100g: const Value(1)));
      await db.into(db.foods).insert(FoodsCompanion.insert(clientId: 'mystery', name: 'Mystery', caloriesPer100g: 100, proteinPer100g: 5));
      await db.into(db.recipes).insert(RecipesCompanion.insert(clientId: 'r', name: 'Bowl'));
      await db.into(db.recipeIngredients).insert(RecipeIngredientsCompanion.insert(
          clientId: 'i1', recipeClientId: 'r', foodClientId: 'oats', quantityInGrams: 50));
      await db.into(db.recipeIngredients).insert(RecipeIngredientsCompanion.insert(
          clientId: 'i2', recipeClientId: 'r', foodClientId: 'mystery', quantityInGrams: 200));

      final recipe = (await repo.watchAll().first).single;

      final oats = recipe.ingredients.firstWhere((i) => i.foodClientId == 'oats');
      expect(oats.fiber, 5);
      expect(oats.sugar, 0.5);
      final mystery = recipe.ingredients.firstWhere((i) => i.foodClientId == 'mystery');
      expect(mystery.fiber, isNull);
      expect(mystery.sugar, isNull);
      expect(recipe.fiberSugar.fiber, 5);
      expect(recipe.fiberSugar.partial, isTrue);
    });
  });
}
