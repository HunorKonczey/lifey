import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/ads/interstitial_manager.dart';
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
import 'package:lifey/features/nutrition/presentation/widgets/add_meal_entry_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

const _chicken =
    Food(clientId: 'chicken', name: 'Chicken', caloriesPer100g: 165, proteinPer100g: 31);

class _FakeMealController extends MealController {
  final logged = <List<MealEntryInput>>[];

  @override
  Stream<List<Meal>> build() => Stream.value(const []);

  @override
  Future<String> logMeal({
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
    String? name,
  }) async {
    logged.add(entries);
    return 'meal-1';
  }

  @override
  Future<void> updateMeal(
    String clientId, {
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
    String? name,
  }) async {}
}

class _NoAds extends InterstitialManager {
  _NoAds(super.ref);

  @override
  Future<void> maybeShow(BuildContext context, InterstitialReason reason) async {}
}

void main() {
  late _FakeMealController meals;

  Future<void> pumpAndOpen(WidgetTester tester) async {
    meals = _FakeMealController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealControllerProvider.overrideWith(() => meals),
          interstitialManagerProvider.overrideWith(_NoAds.new),
          remainingBudgetProvider
              .overrideWithValue(const AsyncValue<RemainingBudget>.loading()),
          foodSearchProvider.overrideWith((ref) => Stream.value(const [_chicken])),
          foodUsageProvider.overrideWith((ref) => Stream.value({
                'chicken': FoodUsage(
                    lastUsedAt: DateTime(2026, 9, 1), useCount: 3, lastGrams: 150),
              })),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LogMealScreen(initialFood: _chicken)),
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

  Future<void> dismissSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(20, 20)); // modal barrier above the sheet
    await tester.pumpAndSettle();
  }

  testWidgets('opens the add-food sheet on the given food right away', (tester) async {
    await pumpAndOpen(tester);

    expect(find.byType(LogMealScreen), findsOneWidget);
    expect(find.byType(AddMealEntrySheet), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Chicken'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '150'), findsOneWidget);
  });

  testWidgets('Add puts the entry on the meal and saves it once', (tester) async {
    await pumpAndOpen(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.byType(AddMealEntrySheet), findsNothing);
    expect(find.byType(LogMealScreen), findsOneWidget);
    expect(meals.logged, hasLength(1));
    expect(meals.logged.single.single.foodClientId, 'chicken');
    expect(meals.logged.single.single.grams, 150);
  });

  testWidgets('dismissing the auto-opened sheet closes the empty meal screen', (tester) async {
    await pumpAndOpen(tester);

    await dismissSheet(tester);

    expect(find.byType(LogMealScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(meals.logged, isEmpty);
  });

  testWidgets('dismissing a later add-food sheet keeps the screen open', (tester) async {
    await pumpAndOpen(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add food').last);
    await tester.pumpAndSettle();
    expect(find.byType(AddMealEntrySheet), findsOneWidget);
    await dismissSheet(tester);

    expect(find.byType(LogMealScreen), findsOneWidget);
  });
}
