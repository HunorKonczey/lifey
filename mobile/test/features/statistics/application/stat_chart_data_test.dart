import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/application/meal_controller.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/statistics/application/stat_chart_data.dart';
import 'package:lifey/features/statistics/application/stat_metric_controller.dart';
import 'package:lifey/features/statistics/application/stat_summary_data.dart';
import 'package:lifey/features/statistics/application/stats_range_controller.dart';
import 'package:lifey/features/statistics/domain/stat_metric.dart';
import 'package:lifey/features/steps/data/step_count_repository.dart';
import 'package:lifey/features/steps/domain/daily_step_count.dart';
import 'package:lifey/features/water/data/water_entry_repository.dart';
import 'package:lifey/features/water/domain/water_entry.dart';
import 'package:lifey/features/weight/application/weight_controller.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/shared/widgets/charts/stats_range.dart';
import 'package:lifey/shared/widgets/charts/time_series_chart.dart';

/// Anchors every test's dates relative to "now" rather than hard-coding
/// calendar dates, so the suite never goes stale or flakes around a fixed
/// date. [offset] is days back from today's local midnight.
final _now = DateTime.now();
DateTime _day(int offset) =>
    DateTime(_now.year, _now.month, _now.day).subtract(Duration(days: offset));

Meal _meal(
  DateTime dateTime, {
  double calories = 0,
  double protein = 0,
  double carbs = 0,
  double fat = 0,
}) {
  return Meal(
    clientId: 'meal-${dateTime.microsecondsSinceEpoch}-$calories-$protein',
    dateTime: dateTime,
    mealType: MealType.breakfast,
    entries: [
      MealEntry(
        foodClientId: 'food',
        foodName: 'Food',
        quantityInGrams: 100,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      ),
    ],
  );
}

WorkoutSession _session({
  required DateTime startedAt,
  DateTime? finishedAt,
  double? activeCalories,
}) {
  return WorkoutSession(
    clientId: 'session-${startedAt.microsecondsSinceEpoch}',
    startedAt: startedAt,
    finishedAt: finishedAt,
    exercises: const [],
    sets: const [],
    activeCalories: activeCalories,
  );
}

WaterEntry _water(DateTime consumedAt, double liters) {
  return WaterEntry(
    clientId: 'water-${consumedAt.microsecondsSinceEpoch}',
    consumedAt: consumedAt,
    volumeLiters: liters,
  );
}

WeightEntry _weight(DateTime date, double weight, {required DateTime recordedAt}) {
  return WeightEntry(
    clientId: 'weight-${date.microsecondsSinceEpoch}-${recordedAt.microsecondsSinceEpoch}',
    date: date,
    weight: weight,
    recordedAt: recordedAt,
  );
}

class _FakeMealController extends MealController {
  _FakeMealController(this._meals);
  final List<Meal> _meals;

  @override
  Stream<List<Meal>> build() => Stream.value(_meals);
}

class _FakeWorkoutSessionController extends WorkoutSessionController {
  _FakeWorkoutSessionController(this._sessions);
  final List<WorkoutSession> _sessions;

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(_sessions);
}

class _FakeWeightController extends WeightController {
  _FakeWeightController(this._entries);
  final List<WeightEntry> _entries;

  @override
  Stream<List<WeightEntry>> build() => Stream.value(_entries);
}

/// Builds a container with only the underlying feature stream(s) the test
/// actually needs overridden — `statChartDataProvider` only ever watches the
/// one source the selected [StatMetric] requires, so the others are left
/// untouched (and never initialized).
ProviderContainer _buildContainer({
  List<Meal>? meals,
  List<WorkoutSession>? sessions,
  List<WaterEntry>? water,
  List<WeightEntry>? weights,
  List<DailyStepCount>? steps,
}) {
  return ProviderContainer(
    overrides: [
      if (meals != null) mealControllerProvider.overrideWith(() => _FakeMealController(meals)),
      if (sessions != null)
        workoutSessionControllerProvider.overrideWith(
          () => _FakeWorkoutSessionController(sessions),
        ),
      if (water != null) allWaterEntriesProvider.overrideWith((ref) => Stream.value(water)),
      if (weights != null)
        weightControllerProvider.overrideWith(() => _FakeWeightController(weights)),
      if (steps != null) allStepCountsProvider.overrideWith((ref) => Stream.value(steps)),
    ],
  );
}

/// (date, value) pairs are easier to assert on than [TimeSeriesPoint]
/// instances, which don't override `==`.
List<(DateTime, double)> _asPairs(List<TimeSeriesPoint> points) =>
    points.map((p) => (p.date, p.value)).toList();

void main() {
  group('statChartDataProvider', () {
    test('calories: sums meal calories per day', () async {
      final container = _buildContainer(meals: [
        _meal(_day(1).add(const Duration(hours: 8)), calories: 400),
        _meal(_day(1).add(const Duration(hours: 18)), calories: 250),
        _meal(_day(0).add(const Duration(hours: 8)), calories: 100),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.calories);
      // Plain `container.read(provider.future)` never resolves on its own —
      // nothing drives the stream without an active listener — so every
      // wait below pairs it with a no-op `listen`, the way riverpod's own
      // test suite does.
      await container.listen(mealControllerProvider.future, (previous, next) {}).read();

      final points = container.read(statChartDataProvider).value!;
      expect(_asPairs(points), [(_day(1), 650.0), (_day(0), 100.0)]);
    });

    test('protein/carbs/fat each pick their own macro field, not calories', () async {
      final meals = [
        _meal(_day(0), calories: 999, protein: 30, carbs: 40, fat: 10),
      ];

      for (final (metric, expected) in [
        (StatMetric.protein, 30.0),
        (StatMetric.carbs, 40.0),
        (StatMetric.fat, 10.0),
      ]) {
        final container = _buildContainer(meals: meals);
        addTearDown(container.dispose);

        container.read(statMetricControllerProvider.notifier).select(metric);
        await container.listen(mealControllerProvider.future, (previous, next) {}).read();

        final points = container.read(statChartDataProvider).value!;
        expect(_asPairs(points), [(_day(0), expected)]);
      }
    });

    test(
      'workoutMinutes: sums finished session durations per day, skipping in-progress sessions',
      () async {
        final container = _buildContainer(sessions: [
          _session(
            startedAt: _day(1).add(const Duration(hours: 8)),
            finishedAt: _day(1).add(const Duration(hours: 9, minutes: 30)),
          ),
          _session(
            startedAt: _day(1).add(const Duration(hours: 18)),
            finishedAt: _day(1).add(const Duration(hours: 18, minutes: 45)),
          ),
          // In-progress on day 0 — must not count as a 0-minute workout.
          _session(startedAt: _day(0).add(const Duration(hours: 7))),
          _session(
            startedAt: _day(0).add(const Duration(hours: 8)),
            finishedAt: _day(0).add(const Duration(hours: 8, minutes: 20)),
          ),
        ]);
        addTearDown(container.dispose);

        container.read(statMetricControllerProvider.notifier).select(StatMetric.workoutMinutes);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        final points = container.read(statChartDataProvider).value!;
        expect(_asPairs(points), [(_day(1), 135.0), (_day(0), 20.0)]);
      },
    );

    test('workoutCount: counts every session per day, including in-progress ones', () async {
      final container = _buildContainer(sessions: [
        _session(startedAt: _day(1).add(const Duration(hours: 8)), finishedAt: _day(1)),
        _session(startedAt: _day(1).add(const Duration(hours: 18)), finishedAt: _day(1)),
        _session(startedAt: _day(0).add(const Duration(hours: 7))), // in progress
        _session(startedAt: _day(0).add(const Duration(hours: 8)), finishedAt: _day(0)),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.workoutCount);
      await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

      final points = container.read(statChartDataProvider).value!;
      expect(_asPairs(points), [(_day(1), 2.0), (_day(0), 2.0)]);
    });

    test('activeCalories: sums only sessions that have a value, per day', () async {
      final container = _buildContainer(sessions: [
        _session(startedAt: _day(2).add(const Duration(hours: 8)), activeCalories: 300),
        _session(startedAt: _day(2).add(const Duration(hours: 18))), // no Apple Health data
        _session(startedAt: _day(1).add(const Duration(hours: 8)), activeCalories: 150),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.activeCalories);
      await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

      final points = container.read(statChartDataProvider).value!;
      expect(_asPairs(points), [(_day(2), 300.0), (_day(1), 150.0)]);
    });

    test('water: sums volume per day across entries/sources', () async {
      final container = _buildContainer(water: [
        _water(_day(1).add(const Duration(hours: 8)), 0.5),
        _water(_day(1).add(const Duration(hours: 14)), 0.75),
        _water(_day(0).add(const Duration(hours: 9)), 1.0),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.water);
      await container.listen(allWaterEntriesProvider.future, (previous, next) {}).read();

      final points = container.read(statChartDataProvider).value!;
      expect(_asPairs(points), [(_day(1), 1.25), (_day(0), 1.0)]);
    });

    test('weight: keeps only the most recently recorded entry per day', () async {
      // Mirrors WeightRepository.watchAll()'s contract: already ordered date
      // desc, then recordedAt desc.
      final container = _buildContainer(weights: [
        _weight(_day(0), 81.2, recordedAt: _day(0).add(const Duration(hours: 20))),
        _weight(_day(0), 80.9, recordedAt: _day(0).add(const Duration(hours: 7))),
        _weight(_day(1), 81.5, recordedAt: _day(1).add(const Duration(hours: 7))),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.weight);
      await container.listen(weightControllerProvider.future, (previous, next) {}).read();

      final points = container.read(statChartDataProvider).value!;
      expect(_asPairs(points), [(_day(1), 81.5), (_day(0), 81.2)]);
    });

    test('returns an empty list when the underlying source has no data', () async {
      final container = _buildContainer(meals: []);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.calories);
      await container.listen(mealControllerProvider.future, (previous, next) {}).read();

      final points = container.read(statChartDataProvider).value!;
      expect(points, isEmpty);
    });

    test(
      'range cutoff: excludes days older than the range, includes the boundary day',
      () async {
        // StatsRange.week's cutoff is exactly 6 days back.
        final container = _buildContainer(meals: [
          _meal(_day(6), calories: 100), // on the boundary — included
          _meal(_day(7), calories: 200), // one day too old — excluded
        ]);
        addTearDown(container.dispose);

        container.read(statMetricControllerProvider.notifier).select(StatMetric.calories);
        container.read(statsRangeControllerProvider.notifier).select(StatsRange.week);
        await container.listen(mealControllerProvider.future, (previous, next) {}).read();

        final points = container.read(statChartDataProvider).value!;
        expect(_asPairs(points), [(_day(6), 100.0)]);
      },
    );

    test('StatsRange.all has no cutoff', () async {
      final container = _buildContainer(meals: [
        _meal(_day(1000), calories: 100),
        _meal(_day(0), calories: 200),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.calories);
      container.read(statsRangeControllerProvider.notifier).select(StatsRange.all);
      await container.listen(mealControllerProvider.future, (previous, next) {}).read();

      final points = container.read(statChartDataProvider).value!;
      expect(_asPairs(points), [(_day(1000), 100.0), (_day(0), 200.0)]);
    });
  });

  group('statSummaryProvider', () {
    test('empty points produce StatSummary.empty', () async {
      final container = _buildContainer(meals: []);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.calories);
      await container.listen(mealControllerProvider.future, (previous, next) {}).read();

      final summary = container.read(statSummaryProvider).value!;
      expect(summary.sum, 0);
      expect(summary.average, 0);
      expect(summary.min, 0);
      expect(summary.max, 0);
      expect(summary.trend, isNull);
      expect(summary.trendPercent, isNull);
    });

    test('a single point has no trend (nothing to compare it against)', () async {
      final container = _buildContainer(meals: [_meal(_day(0), calories: 150)]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.calories);
      await container.listen(mealControllerProvider.future, (previous, next) {}).read();

      final summary = container.read(statSummaryProvider).value!;
      expect(summary.sum, 150);
      expect(summary.average, 150);
      expect(summary.min, 150);
      expect(summary.max, 150);
      expect(summary.trend, isNull);
      expect(summary.trendPercent, isNull);
    });

    test('splits a two-day range in half to compute sum/average/extremes/trend', () async {
      final container = _buildContainer(meals: [
        _meal(_day(1), calories: 100),
        _meal(_day(0), calories: 200),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.calories);
      await container.listen(mealControllerProvider.future, (previous, next) {}).read();

      final summary = container.read(statSummaryProvider).value!;
      expect(summary.sum, 300);
      expect(summary.average, 150);
      expect(summary.min, 100);
      expect(summary.max, 200);
      // Earlier half (day 1, avg 100) vs later half (day 0, avg 200).
      expect(summary.trend, 100);
      expect(summary.trendPercent, 100);
    });
  });

  group('availableStatMetricsProvider', () {
    test('is empty when none of the underlying sources have any data', () async {
      final container =
          _buildContainer(meals: [], sessions: [], water: [], weights: [], steps: []);
      addTearDown(container.dispose);

      await container.listen(mealControllerProvider.future, (previous, next) {}).read();
      await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();
      await container.listen(allWaterEntriesProvider.future, (previous, next) {}).read();
      await container.listen(weightControllerProvider.future, (previous, next) {}).read();
      await container.listen(allStepCountsProvider.future, (previous, next) {}).read();

      expect(container.read(availableStatMetricsProvider), isEmpty);
    });

    test('includes activeCalories/workoutMinutes only when a session actually has a value',
        () async {
      final container = _buildContainer(
        meals: [],
        // Neither session has activeCalories, and neither has finished, so
        // workoutCount is the only workout metric that should show up.
        sessions: [_session(startedAt: _day(0))],
        water: [],
        weights: [],
        steps: [],
      );
      addTearDown(container.dispose);

      await container.listen(mealControllerProvider.future, (previous, next) {}).read();
      await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();
      await container.listen(allWaterEntriesProvider.future, (previous, next) {}).read();
      await container.listen(weightControllerProvider.future, (previous, next) {}).read();
      await container.listen(allStepCountsProvider.future, (previous, next) {}).read();

      expect(container.read(availableStatMetricsProvider), {StatMetric.workoutCount});
    });

    test('includes every metric whose source has at least one usable value', () async {
      final container = _buildContainer(
        meals: [_meal(_day(0), calories: 100)],
        sessions: [
          _session(
            startedAt: _day(0),
            finishedAt: _day(0).add(const Duration(minutes: 30)),
            activeCalories: 200,
          ),
        ],
        water: [_water(_day(0), 0.5)],
        weights: [_weight(_day(0), 80, recordedAt: _day(0))],
        steps: [],
      );
      addTearDown(container.dispose);

      await container.listen(mealControllerProvider.future, (previous, next) {}).read();
      await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();
      await container.listen(allWaterEntriesProvider.future, (previous, next) {}).read();
      await container.listen(weightControllerProvider.future, (previous, next) {}).read();
      await container.listen(allStepCountsProvider.future, (previous, next) {}).read();

      expect(container.read(availableStatMetricsProvider), {
        StatMetric.calories,
        StatMetric.protein,
        StatMetric.carbs,
        StatMetric.fat,
        StatMetric.workoutCount,
        StatMetric.workoutMinutes,
        StatMetric.activeCalories,
        StatMetric.water,
        StatMetric.weight,
      });
    });
  });
}
