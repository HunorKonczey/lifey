import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/features/nutrition/application/meal_controller.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/statistics/application/stat_kind_filter_controller.dart';
import 'package:lifey/features/statistics/application/stat_metric_controller.dart';
import 'package:lifey/features/statistics/application/stats_range_controller.dart';
import 'package:lifey/features/statistics/domain/stat_kind_filter.dart';
import 'package:lifey/features/statistics/domain/stat_metric.dart';
import 'package:lifey/features/statistics/presentation/statistics_screen.dart';
import 'package:lifey/features/statistics/presentation/widgets/stat_metric_chips.dart';
import 'package:lifey/features/steps/data/step_count_repository.dart';
import 'package:lifey/features/steps/domain/daily_step_count.dart';
import 'package:lifey/features/water/data/water_entry_repository.dart';
import 'package:lifey/features/weight/application/weight_controller.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/charts/bar_chart.dart';
import 'package:lifey/shared/widgets/charts/stats_range.dart';
import 'package:lifey/shared/widgets/charts/time_series_chart.dart';
import 'package:lifey/shared/widgets/ds/lifey_segmented.dart';
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

class _FakeWorkoutSessionController extends WorkoutSessionController {
  _FakeWorkoutSessionController(this._sessions);
  final List<WorkoutSession> _sessions;

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(_sessions);
}

class _EmptyWeightController extends WeightController {
  @override
  Stream<List<WeightEntry>> build() => Stream.value(const []);
}

class _FakeSettingsController extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

DateTime _day(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo, 12);
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

List<Meal> _mealsOnDays(Iterable<int> daysAgo) => [for (final d in daysAgo) _meal(_day(d), calories: 2000)];

WorkoutSession _workout(int daysAgo) => WorkoutSession(
      clientId: 'w-$daysAgo',
      startedAt: _day(daysAgo),
      finishedAt: _day(daysAgo).add(const Duration(minutes: 45)),
      exercises: const [],
      sets: const [],
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  MealController Function()? meals,
  List<WorkoutSession> sessions = const [],
  List<DailyStepCount> steps = const [],
  StatMetric? metric,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 900),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      // `availableStatMetricsProvider` watches all four feature sources
      // unconditionally (it needs to know about every metric, not just the
      // selected one), so every source needs a fake here, not just meals.
      overrides: [
        mealControllerProvider.overrideWith(meals ?? () => _FakeMealController(const [])),
        workoutSessionControllerProvider.overrideWith(() => _FakeWorkoutSessionController(sessions)),
        weightControllerProvider.overrideWith(_EmptyWeightController.new),
        allWaterEntriesProvider.overrideWith((ref) => Stream.value(const [])),
        allStepCountsProvider.overrideWith((ref) => Stream.value(steps)),
        settingsControllerProvider.overrideWith(_FakeSettingsController.new),
        // `null` (unlimited) keeps every range unlocked without a database.
        historyCutoffProvider.overrideWithValue(null),
        // BannerAdSlot is embedded on this screen.
        adsEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(builder: (context) {
          container = ProviderScope.containerOf(context);
          return const StatisticsScreen();
        }),
      ),
    ),
  );
  if (metric != null) {
    container.read(statMetricControllerProvider.notifier).select(metric);
  }
  // Fake streams emit on a microtask; the only endless animation is the
  // loading spinner, gone by then, so `pumpAndSettle` is safe.
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('a range without data says so and keeps the range switcher', (tester) async {
    await _pump(tester);

    expect(find.text('No data in this range'), findsOneWidget);
    expect(find.byType(LifeyBarChart), findsNothing);
    expect(find.byType(LifeySegmented<StatsRange>), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);
  });

  testWidgets('daily-total metrics show the daily average, a bar chart and the range switcher',
      (tester) async {
    await _pump(tester, meals: () => _FakeMealController(_mealsOnDays([1, 2, 3, 10])));

    expect(find.text('Daily average · last 30 days'), findsOneWidget);
    expect(find.textContaining('2,000'), findsWidgets);
    expect(find.byType(LifeyBarChart), findsOneWidget);
    expect(find.byType(TimeSeriesChart), findsNothing);
    expect(find.byType(LifeySegmented<StatsRange>), findsOneWidget);
    // Nothing to compare with: the prior 30 days are empty, so no trend chip.
    expect(find.textContaining('vs prior'), findsNothing);
  });

  testWidgets('a trend chip appears when the period before has data', (tester) async {
    await _pump(
      tester,
      meals: () => _FakeMealController([..._mealsOnDays([1, 2, 3]), ..._mealsOnDays([35, 36, 37])]),
    );

    expect(find.textContaining('vs prior 30 d'), findsOneWidget);
  });

  testWidgets('picking a metric chip switches the metric', (tester) async {
    final container = await _pump(
      tester,
      meals: () => _FakeMealController(_mealsOnDays([1, 2])),
      steps: [DailyStepCount(clientId: 's1', date: _day(1), steps: 8000)],
    );

    // The row scrolls sideways: Steps is past the right edge.
    await tester.scrollUntilVisible(
      find.text('Steps'),
      100,
      scrollable: find.descendant(of: find.byType(StatMetricChips), matching: find.byType(Scrollable)),
    );
    await tester.ensureVisible(find.text('Steps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Steps'));
    await tester.pumpAndSettle();

    expect(container.read(statMetricControllerProvider), StatMetric.steps);
    expect(find.byType(TimeSeriesChart), findsOneWidget);
    expect(find.byType(LifeyBarChart), findsNothing);
  });

  testWidgets('workouts are charted per calendar week, with the grouping footnote', (tester) async {
    await _pump(
      tester,
      sessions: [_workout(1), _workout(3), _workout(9), _workout(20)],
      metric: StatMetric.workoutCount,
    );

    expect(find.byType(LifeyBarChart), findsOneWidget);
    expect(find.text('Grouped by week so a single day never looks like a spike.'), findsOneWidget);
    // 30 days span 5–6 calendar weeks, never 30 bars.
    final bars = tester.widget<LifeyBarChart>(find.byType(LifeyBarChart)).bars;
    expect(bars.length, inInclusiveRange(5, 6));
    expect(bars.last.highlighted, isTrue);
  });

  testWidgets('a 7-day range draws workouts by day, without the weekly footnote', (tester) async {
    final container = await _pump(tester, sessions: [_workout(1), _workout(3)], metric: StatMetric.workoutCount);
    container.read(statsRangeControllerProvider.notifier).select(StatsRange.week);
    await tester.pumpAndSettle();

    expect(tester.widget<LifeyBarChart>(find.byType(LifeyBarChart)).bars, hasLength(7));
    expect(find.textContaining('Grouped by week'), findsNothing);
  });

  testWidgets('the strength / cardio switch shows only for the workout metrics', (tester) async {
    final container = await _pump(tester, sessions: [_workout(1)], metric: StatMetric.workoutCount);

    expect(find.byType(LifeySegmented<StatKindFilter>), findsOneWidget);
    expect(container.read(statKindFilterControllerProvider), StatKindFilter.all);

    await tester.tap(find.text('Strength'));
    await tester.pumpAndSettle();
    expect(container.read(statKindFilterControllerProvider), StatKindFilter.strength);

    await tester.tap(find.text('Cardio'));
    await tester.pumpAndSettle();
    expect(container.read(statKindFilterControllerProvider), StatKindFilter.cardio);

    container.read(statMetricControllerProvider.notifier).select(StatMetric.calories);
    await tester.pumpAndSettle();
    expect(find.byType(LifeySegmented<StatKindFilter>), findsNothing);
  });

  testWidgets('shows ErrorView when the underlying stream errors', (tester) async {
    await _pump(tester, meals: _ErrorMealController.new);

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.byType(LifeyBarChart), findsNothing);
  });

  for (final (name, locale, size, scale) in [
    ('Hungarian at 360 dp', const Locale('hu'), const Size(360, 780), 1.0),
    ('English at 360 dp and 130 % text', const Locale('en'), const Size(360, 780), 1.3),
    ('Hungarian at 360 dp and 130 % text', const Locale('hu'), const Size(360, 780), 1.3),
  ]) {
    testWidgets('lays out without overflow: $name', (tester) async {
      final container = await _pump(
        tester,
        meals: () => _FakeMealController([..._mealsOnDays([1, 2, 3, 12]), ..._mealsOnDays([35, 40])]),
        sessions: [_workout(1), _workout(3), _workout(9)],
        steps: [
          DailyStepCount(clientId: 's1', date: _day(1), steps: 8000),
          DailyStepCount(clientId: 's2', date: _day(2), steps: 4000),
        ],
        locale: locale,
        size: size,
        textScale: scale,
      );
      for (final m in [StatMetric.calories, StatMetric.workoutCount, StatMetric.workoutMinutes, StatMetric.steps]) {
        container.read(statMetricControllerProvider.notifier).select(m);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$m');
      }
    });
  }
}
