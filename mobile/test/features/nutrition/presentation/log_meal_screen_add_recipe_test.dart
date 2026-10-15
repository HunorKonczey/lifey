import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/ads/interstitial_manager.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/nutrition/application/food_controller.dart';
import 'package:lifey/features/nutrition/application/food_usage_provider.dart';
import 'package:lifey/features/nutrition/application/meal_controller.dart';
import 'package:lifey/features/nutrition/application/remaining_budget_provider.dart';
import 'package:lifey/features/nutrition/data/meal_repository.dart';
import 'package:lifey/features/nutrition/domain/food.dart';
import 'package:lifey/features/nutrition/domain/food_usage.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/nutrition/domain/remaining_budget.dart';
import 'package:lifey/features/nutrition/presentation/log_meal_screen.dart';
import 'package:lifey/features/nutrition/presentation/widgets/add_recipe_sheet.dart';
import 'package:lifey/features/recipes/application/recipes_controller.dart';
import 'package:lifey/features/recipes/domain/recipe.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/l10n/app_localizations.dart';

const _chicken = Food(clientId: 'chicken', name: 'Chicken', caloriesPer100g: 165, proteinPer100g: 31);

RecipeIngredient _ingredient(String name, double grams, double kcal) => RecipeIngredient(
      foodClientId: 'food-$name',
      foodName: name,
      quantityInGrams: grams,
      calories: kcal,
      protein: 0,
      carbs: 0,
      fat: 0,
    );

/// Two servings: 300 g beans + 200 g rice.
final _chilli = Recipe(
  clientId: 'chilli',
  name: 'Chilli',
  servings: 2,
  ingredients: [_ingredient('Beans', 300, 300), _ingredient('Rice', 200, 260)],
);

class _Saved {
  _Saved(this.entries, this.name);
  final List<MealEntryInput> entries;
  final String? name;
}

class _FakeMealController extends MealController {
  final created = <_Saved>[];
  final updated = <_Saved>[];

  @override
  Stream<List<Meal>> build() => Stream.value(const []);

  @override
  Future<String> logMeal({
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
    String? name,
  }) async {
    created.add(_Saved(entries, name));
    return 'meal-1';
  }

  @override
  Future<void> updateMeal(
    String clientId, {
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
    String? name,
  }) async {
    updated.add(_Saved(entries, name));
  }
}

class _FakeRecipes extends RecipeController {
  @override
  Stream<List<Recipe>> build() => Stream.value([_chilli]);
}

class _NoGoalSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

class _NoAds extends InterstitialManager {
  _NoAds(super.ref);

  @override
  Future<void> maybeShow(BuildContext context, InterstitialReason reason) async {}
}

void main() {
  late _FakeMealController meals;

  Future<void> open(WidgetTester tester, {Meal? meal, Food? initialFood}) async {
    tester.view.physicalSize = const Size(411 * 2.625, 923 * 2.625);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    meals = _FakeMealController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealControllerProvider.overrideWith(() => meals),
          recipeControllerProvider.overrideWith(_FakeRecipes.new),
          settingsControllerProvider.overrideWith(_NoGoalSettings.new),
          interstitialManagerProvider.overrideWith(_NoAds.new),
          isOfflineProvider.overrideWith((ref) => Stream.value(false)),
          aiCreditsProvider.overrideWithValue(null),
          remainingBudgetProvider.overrideWithValue(const AsyncValue<RemainingBudget>.loading()),
          foodSearchProvider.overrideWith((ref) => Stream.value(const [_chicken])),
          foodUsageProvider.overrideWith((ref) => Stream.value({
                'chicken': FoodUsage(lastUsedAt: DateTime(2026, 9, 1), useCount: 3, lastGrams: 150),
              })),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LogMealScreen(meal: meal, initialFood: initialFood)),
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

  Future<void> addChilli(WidgetTester tester) async {
    await tester.tap(find.text('Add recipe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chilli'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add to meal'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the four actions', (tester) async {
    await open(tester);

    for (final label in ['Add food', 'Add recipe', 'Macros only', 'From photo']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('a recipe becomes its ingredients, saved under the recipe name', (tester) async {
    await open(tester);

    await addChilli(tester);

    expect(find.byType(AddRecipeSheet), findsNothing);
    expect(find.text('Beans'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(meals.created, hasLength(1));
    final saved = meals.created.single;
    expect(saved.name, 'Chilli');
    // One of the two servings: half of every ingredient.
    expect(saved.entries.map((e) => (e.foodClientId, e.grams)), [('food-Beans', 150.0), ('food-Rice', 100.0)]);
    expect(saved.entries.map((e) => e.recipeClientId), everyElement('chilli'));
  });

  testWidgets('a food added after the recipe drops the name', (tester) async {
    await open(tester);
    await addChilli(tester);

    await tester.tap(find.text('Add food'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Chicken'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add to meal'));
    await tester.pumpAndSettle();

    expect(meals.updated, isNotEmpty);
    expect(meals.updated.last.name, isNull);
    expect(meals.updated.last.entries.map((e) => e.foodClientId), ['food-Beans', 'food-Rice', 'chicken']);
    // The recipe's rows keep their tag, the food added by hand has none.
    expect(meals.updated.last.entries.map((e) => e.recipeClientId), ['chilli', 'chilli', null]);
  });

  testWidgets('a recipe added to a meal that already has a food is not named', (tester) async {
    await open(tester, initialFood: _chicken);
    await tester.tap(find.widgetWithText(FilledButton, 'Add to meal'));
    await tester.pumpAndSettle();
    expect(meals.created.single.name, isNull);

    await addChilli(tester);

    expect(meals.updated.last.name, isNull);
    expect(meals.updated.last.entries, hasLength(3));
  });

  testWidgets('a second recipe leaves the meal unnamed', (tester) async {
    await open(tester);
    await addChilli(tester);
    expect(meals.created.single.name, 'Chilli');

    await addChilli(tester);

    expect(meals.updated.last.name, isNull);
    expect(meals.updated.last.entries, hasLength(4));
  });

  testWidgets('the recipe name sticks through later saves of the same meal', (tester) async {
    await open(tester);
    await addChilli(tester);

    // Changing the meal type saves the meal again, still just the recipe.
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();

    expect(meals.updated.last.name, 'Chilli');
  });

  testWidgets('dismissing the sheet changes nothing and keeps the screen open', (tester) async {
    await open(tester);

    await tester.tap(find.text('Add recipe'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(LogMealScreen), findsOneWidget);
    expect(meals.created, isEmpty);
  });

  testWidgets('editing a named meal keeps its name when a recipe is added', (tester) async {
    final meal = Meal(
      clientId: 'm1',
      dateTime: DateTime(2026, 10, 1, 12),
      mealType: MealType.lunch,
      name: 'Old recipe',
      entries: const [
        MealEntry(
          foodClientId: 'chicken',
          foodName: 'Chicken',
          quantityInGrams: 100,
          calories: 165,
          protein: 31,
          carbs: 0,
          fat: 3,
        ),
      ],
    );
    await open(tester, meal: meal);

    await addChilli(tester);

    expect(meals.updated.last.name, 'Old recipe');
    expect(meals.updated.last.entries, hasLength(3));
  });

  testWidgets('the recipe tags of a meal being edited survive an edit of another row', (tester) async {
    MealEntry entry(String food, {String? recipe}) => MealEntry(
          foodClientId: food,
          foodName: food,
          quantityInGrams: 100,
          calories: 100,
          protein: 5,
          carbs: 10,
          fat: 2,
          recipeClientId: recipe,
        );
    final meal = Meal(
      clientId: 'm1',
      dateTime: DateTime(2026, 10, 1, 12),
      mealType: MealType.lunch,
      entries: [entry('Beans', recipe: 'chilli'), entry('Rice', recipe: 'chilli'), entry('Salad')],
    );
    await open(tester, meal: meal);

    // Remove the salad (the last row): the autosave carries the other rows with their tags.
    await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    final saved = meals.updated.last.entries;
    expect(saved.map((e) => (e.foodClientId, e.recipeClientId)), [('Beans', 'chilli'), ('Rice', 'chilli')]);
  });
}
