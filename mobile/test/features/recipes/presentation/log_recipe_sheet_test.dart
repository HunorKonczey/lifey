import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/network/dio_client.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/core/sync/sync_engine_provider.dart';
import 'package:lifey/features/nutrition/application/food_controller.dart';
import 'package:lifey/features/nutrition/data/meal_repository.dart';
import 'package:lifey/features/nutrition/domain/food.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/recipes/domain/recipe.dart';
import 'package:lifey/features/recipes/presentation/widgets/log_recipe_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// See test/core/sync/food_update_http_method_test.dart's comment — the
/// outbox's fire-and-forget kick can otherwise race the test's DB teardown.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream,
      Future<void>? cancelFuture) {
    throw UnimplementedError('never called — sync is a no-op in this test');
  }
}

void main() {
  late ProviderContainer container;
  late MealRepository repo;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = _FailingAdapter();
    final db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      dioClientProvider.overrideWithValue(dio),
      appDatabaseProvider.overrideWithValue(db),
      syncEngineProvider.overrideWith((ref) => _NoopSyncEngine(db, dio)),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);
    repo = container.read(mealRepositoryProvider);
  });

  Future<Food> makeFood(String name) => container.read(foodControllerProvider.notifier).addFood(
        name: name,
        calories: 200,
        protein: 20,
      );

  /// Two-serving recipe, so the sheet opens with the part-meal split already
  /// on at divisor 2: chicken defaults to 150 g/portion, rice to 100 g.
  Recipe recipeWith(Food chicken, Food rice) => Recipe(
        clientId: 'recipe-1',
        name: 'Chicken rice',
        servings: 2,
        ingredients: [
          RecipeIngredient(
            foodClientId: chicken.clientId,
            foodName: 'Chicken',
            quantityInGrams: 300,
            calories: 600,
            protein: 60,
            carbs: 0,
            fat: 10,
          ),
          RecipeIngredient(
            foodClientId: rice.clientId,
            foodName: 'Rice',
            quantityInGrams: 200,
            calories: 260,
            protein: 5,
            carbs: 56,
            fat: 1,
          ),
        ],
      );

  Future<void> pumpSheet(WidgetTester tester, Recipe recipe) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => LogRecipeSheet(recipe: recipe),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder gramsField(String text) => find.widgetWithText(TextField, text);

  Future<void> expandIngredients(WidgetTester tester) async {
    await tester.tap(find.text('Adjust ingredients'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    // The expanded ingredient list can push the button below the test
    // viewport — scroll it into view first.
    await tester.ensureVisible(find.text('Log meal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
  }

  testWidgets('an edited ingredient amount is logged; untouched ones keep the divided default',
      (tester) async {
    await tester.runAsync(() async {
      final chicken = await makeFood('Chicken');
      final rice = await makeFood('Rice');
      await pumpSheet(tester, recipeWith(chicken, rice));

      await expandIngredients(tester);
      await tester.enterText(gramsField('150'), '180');
      await submit(tester);

      final meal = (await repo.recentMeals(days: 1)).single;
      final byFood = {for (final e in meal.entries) e.foodClientId: e.quantityInGrams};
      expect(byFood[chicken.clientId], 180);
      expect(byFood[rice.clientId], 100);
    });
  });

  testWidgets('a zero amount leaves that ingredient out of the logged meal', (tester) async {
    await tester.runAsync(() async {
      final chicken = await makeFood('Chicken');
      final rice = await makeFood('Rice');
      await pumpSheet(tester, recipeWith(chicken, rice));

      await expandIngredients(tester);
      await tester.enterText(gramsField('150'), '0');
      await submit(tester);

      final meal = (await repo.recentMeals(days: 1)).single;
      expect(meal.entries.single.foodClientId, rice.clientId);
      expect(meal.entries.single.quantityInGrams, 100);
    });
  });

  testWidgets('changing the divisor rescales defaults but keeps a hand-typed amount',
      (tester) async {
    await tester.runAsync(() async {
      final chicken = await makeFood('Chicken');
      final rice = await makeFood('Rice');
      await pumpSheet(tester, recipeWith(chicken, rice));

      await expandIngredients(tester);
      await tester.enterText(gramsField('150'), '180');
      await tester.ensureVisible(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Rice rescaled to 200/3, chicken keeps the override.
      expect(gramsField('66.67'), findsOneWidget);
      expect(gramsField('180'), findsOneWidget);

      await submit(tester);
      final meal = (await repo.recentMeals(days: 1)).single;
      final byFood = {for (final e in meal.entries) e.foodClientId: e.quantityInGrams};
      expect(byFood[chicken.clientId], 180);
      expect(byFood[rice.clientId], closeTo(66.67, 0.001));
    });
  });

  testWidgets('the reset button restores the recipe-derived amount', (tester) async {
    await tester.runAsync(() async {
      final chicken = await makeFood('Chicken');
      final rice = await makeFood('Rice');
      await pumpSheet(tester, recipeWith(chicken, rice));

      await expandIngredients(tester);
      await tester.enterText(gramsField('150'), '180');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.restart_alt), findsOneWidget);

      await tester.tap(find.byIcon(Icons.restart_alt));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.restart_alt), findsNothing);
      expect(gramsField('150'), findsOneWidget);
    });
  });
}
