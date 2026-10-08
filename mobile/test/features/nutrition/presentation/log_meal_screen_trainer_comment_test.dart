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

const _chicken = Food(clientId: 'chicken', name: 'Chicken', caloriesPer100g: 165, proteinPer100g: 31);

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

Meal _meal({String? trainerComment, DateTime? trainerCommentAt}) => Meal(
      clientId: 'm1',
      id: 5,
      dateTime: DateTime(2026, 9, 24, 12, 30),
      mealType: MealType.lunch,
      entries: const [
        MealEntry(
          foodClientId: 'chicken',
          foodName: 'Chicken',
          quantityInGrams: 150,
          calories: 247,
          protein: 46,
          carbs: 0,
          fat: 5,
        ),
      ],
      trainerComment: trainerComment,
      trainerCommentAt: trainerCommentAt,
    );

Future<void> _open(WidgetTester tester, {Meal? meal}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mealControllerProvider.overrideWith(_FakeMealController.new),
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LogMealScreen(meal: meal),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a meal the trainer commented on shows the whole comment and when it was written (LIF-144)', (tester) async {
    await _open(
      tester,
      meal: _meal(trainerComment: 'Nice protein. Next time add a side of vegetables.', trainerCommentAt: DateTime(2026, 9, 25, 9)),
    );

    expect(find.byKey(const ValueKey('trainer-comment-card')), findsOneWidget);
    expect(find.text('Trainer comment'), findsOneWidget);
    expect(find.text('Nice protein. Next time add a side of vegetables.'), findsOneWidget);
    expect(find.text('Sep 25'), findsOneWidget);
  });

  testWidgets('an uncommented meal, and a new one, have no comment card', (tester) async {
    await _open(tester, meal: _meal());
    expect(find.byKey(const ValueKey('trainer-comment-card')), findsNothing);
  });

  testWidgets('a new meal has no comment card either', (tester) async {
    await _open(tester);
    expect(find.byKey(const ValueKey('trainer-comment-card')), findsNothing);
  });
}
