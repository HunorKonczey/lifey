import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/application/meal_controller.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/statistics/presentation/statistics_screen.dart';
import 'package:lifey/features/steps/data/step_count_repository.dart';
import 'package:lifey/features/water/data/water_entry_repository.dart';
import 'package:lifey/features/weight/application/weight_controller.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/charts/time_series_chart.dart';
import 'package:lifey/shared/widgets/empty_view.dart';
import 'package:lifey/shared/widgets/error_view.dart';

class _FakeMealController extends MealController {
  _FakeMealController(this._meals);
  final List<Meal> _meals;

  @override
  Stream<List<Meal>> build() => Stream.value(_meals);
}

class _ErrorMealController extends MealController {
  @override
  Stream<List<Meal>> build() => Stream.error(Exception('boom'));
}

class _EmptyWorkoutSessionController extends WorkoutSessionController {
  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);
}

class _EmptyWeightController extends WeightController {
  @override
  Stream<List<WeightEntry>> build() => Stream.value(const []);
}

class _FakeSettingsController extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

Meal _meal(DateTime dateTime, {double calories = 100}) {
  return Meal(
    clientId: 'meal-${dateTime.microsecondsSinceEpoch}',
    dateTime: dateTime,
    mealType: MealType.breakfast,
    entries: [
      MealEntry(
        foodClientId: 'food',
        foodName: 'Food',
        quantityInGrams: 100,
        calories: calories,
        protein: 0,
        carbs: 0,
        fat: 0,
      ),
    ],
  );
}

Future<void> _pumpStatisticsScreen(WidgetTester tester, MealController Function() controller) async {
  await tester.pumpWidget(
    ProviderScope(
      // `availableStatMetricsProvider` watches all four feature sources
      // unconditionally (it needs to know about every metric, not just the
      // selected one), so every source needs a fake here, not just meals.
      overrides: [
        mealControllerProvider.overrideWith(controller),
        workoutSessionControllerProvider.overrideWith(_EmptyWorkoutSessionController.new),
        weightControllerProvider.overrideWith(_EmptyWeightController.new),
        allWaterEntriesProvider.overrideWith((ref) => Stream.value(const [])),
        allStepCountsProvider.overrideWith((ref) => Stream.value(const [])),
        settingsControllerProvider.overrideWith(_FakeSettingsController.new),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatisticsScreen(),
      ),
    ),
  );
  // The default metric (calories) reads from `mealControllerProvider`, whose
  // fake `Stream.value`/`Stream.error` emits on a microtask. By the time the
  // stream resolves, the loading spinner (the only indefinitely-animating
  // widget) is gone, so `pumpAndSettle` is safe here.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows EmptyView when the selected metric has no data', (tester) async {
    await _pumpStatisticsScreen(tester, () => _FakeMealController(const []));

    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.byType(TimeSeriesChart), findsNothing);
    expect(find.byType(ErrorView), findsNothing);
  });

  testWidgets('shows the chart and KPI cards when there is data', (tester) async {
    await _pumpStatisticsScreen(tester, () => _FakeMealController([_meal(DateTime.now())]));

    expect(find.byType(TimeSeriesChart), findsOneWidget);
    expect(find.byType(EmptyView), findsNothing);
    expect(find.byType(ErrorView), findsNothing);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Average'), findsOneWidget);
  });

  testWidgets('shows ErrorView when the underlying stream errors', (tester) async {
    await _pumpStatisticsScreen(tester, _ErrorMealController.new);

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.byType(TimeSeriesChart), findsNothing);
    expect(find.byType(EmptyView), findsNothing);
  });
}
