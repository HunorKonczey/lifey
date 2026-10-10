import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/ads/interstitial_manager.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
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
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/l10n/app_localizations.dart';

const _oats = Food(clientId: 'oats', name: 'Oats', caloriesPer100g: 370, proteinPer100g: 13, fiberPer100g: 10, sugarPer100g: 1);

class _FakeMealController extends MealController {
  @override
  Stream<List<Meal>> build() => Stream.value(const []);

  @override
  Future<void> updateMeal(
    String clientId, {
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
    String? name,
  }) async {}
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

MealEntry _entry(String id, double grams, {double? fiber, double? sugar}) => MealEntry(
      foodClientId: id,
      foodName: id,
      quantityInGrams: grams,
      calories: 100,
      protein: 5,
      carbs: 10,
      fat: 2,
      fiber: fiber,
      sugar: sugar,
    );

Meal _meal(List<MealEntry> entries) => Meal(
      clientId: 'm1',
      id: 5,
      dateTime: DateTime(2026, 9, 24, 12, 30),
      mealType: MealType.lunch,
      entries: entries,
    );

Future<void> _open(WidgetTester tester, Meal meal) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mealControllerProvider.overrideWith(_FakeMealController.new),
        settingsControllerProvider.overrideWith(_NoGoalSettings.new),
        interstitialManagerProvider.overrideWith(_NoAds.new),
        isOfflineProvider.overrideWith((ref) => Stream.value(false)),
        aiCreditsProvider.overrideWithValue(null),
        remainingBudgetProvider.overrideWithValue(const AsyncValue<RemainingBudget>.loading()),
        foodSearchProvider.overrideWith((ref) => Stream.value(const [_oats])),
        foodUsageProvider.overrideWith((ref) => Stream.value(<String, FoodUsage>{})),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LogMealScreen(meal: meal),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// LIF-148: the meal editor's summary panel shows the meal's fibre and sugar, from the entries it was opened with.
void main() {
  testWidgets('an edited meal whose foods have fibre and sugar shows the totals under the macros', (tester) async {
    await _open(tester, _meal([_entry('oats', 50, fiber: 5, sugar: 0.5), _entry('apple', 150, fiber: 3.6, sugar: 15)]));

    expect(find.text('Fibre 8.6 g · Sugar 15.5 g'), findsOneWidget);
  });

  testWidgets('a food without a figure makes the line say it is partial', (tester) async {
    await _open(tester, _meal([_entry('oats', 50, fiber: 5, sugar: 0.5), _entry('mystery', 100)]));

    expect(find.text('Fibre 5 g · Sugar 0.5 g · some foods have no figure'), findsOneWidget);
  });

  testWidgets('no figure anywhere: no line', (tester) async {
    await _open(tester, _meal([_entry('mystery', 100)]));

    expect(find.byKey(const Key('fiber-sugar-line')), findsNothing);
  });
}
