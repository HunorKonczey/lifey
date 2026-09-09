import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/features/nutrition/application/meal_controller.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/statistics/application/stat_chart_data.dart';
import 'package:lifey/features/statistics/application/stat_kind_filter_controller.dart';
import 'package:lifey/features/statistics/application/stat_metric_controller.dart';
import 'package:lifey/features/statistics/application/stat_summary_data.dart';
import 'package:lifey/features/statistics/application/stats_range_controller.dart';
import 'package:lifey/features/statistics/domain/stat_kind_filter.dart';
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
/// Calendar arithmetic rather than `subtract(Duration(days:))` — the same
/// reason [StatsRange.cutoff] uses it: an exact 24 h × n duration drifts an
/// hour off local midnight across a DST change, which for a large [offset]
/// produced a date the provider's own local-midnight bucketing could never
/// return.
DateTime _day(int offset) => DateTime(_now.year, _now.month, _now.day - offset);

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

/// A CARDIO-kind session — [activityType] defaults to `'RUNNING'` (DISTANCE
/// family) since most cardio-metric tests care about that family;
/// [distanceMeters]/[elevationGainMeters]/[maxHeartRate] land on
/// [WorkoutSession.cardio] the same way the real repository nests them.
WorkoutSession _cardioSession({
  required DateTime startedAt,
  DateTime? finishedAt,
  String activityType = 'RUNNING',
  int? movingSeconds,
  double? distanceMeters,
  double? elevationGainMeters,
  double? maxHeartRate,
  double? maxAltitudeMeters,
  List<int?> zoneSeconds = const [null, null, null, null, null],
}) {
  return WorkoutSession(
    clientId: 'cardio-session-${startedAt.microsecondsSinceEpoch}',
    startedAt: startedAt,
    finishedAt: finishedAt,
    exercises: const [],
    sets: const [],
    sessionKind: 'CARDIO',
    activityType: activityType,
    movingSeconds: movingSeconds,
    cardio: (distanceMeters != null ||
            elevationGainMeters != null ||
            maxHeartRate != null ||
            maxAltitudeMeters != null ||
            zoneSeconds.any((z) => z != null))
        ? CardioMetrics(
            distanceMeters: distanceMeters,
            elevationGainMeters: elevationGainMeters,
            maxHeartRate: maxHeartRate,
            maxAltitudeMeters: maxAltitudeMeters,
            hrZone1Seconds: zoneSeconds[0],
            hrZone2Seconds: zoneSeconds[1],
            hrZone3Seconds: zoneSeconds[2],
            hrZone4Seconds: zoneSeconds[3],
            hrZone5Seconds: zoneSeconds[4],
          )
        : null,
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
      // This file's tests are about the range cutoff itself, not the
      // entitlement one it's now intersected with (`67` §3.2, D-P6) — that
      // combination has its own coverage in stat_chart_data_history_window_test.dart.
      // Unlimited (`null`) here means the range cutoff alone decides what's
      // visible, exactly as before that intersection existed.
      historyCutoffProvider.overrideWithValue(null),
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

    test(
      'activeCalories: the calorie display of an indoor bike never joins the total '
      '(docs/cardio/51 Q4, C7.6)',
      () async {
        final container = _buildContainer(sessions: [
          WorkoutSession(
            clientId: 'ride-1',
            startedAt: _day(1).add(const Duration(hours: 18)),
            finishedAt: _day(1).add(const Duration(hours: 18, minutes: 30)),
            exercises: const [],
            sets: const [],
            sessionKind: 'CARDIO',
            activityType: 'INDOOR_BIKE',
            movingSeconds: 1800,
            activeCalories: 486,
            // The machine claimed 612 — a number that knows nothing about
            // body weight, which is why it stays out of every total.
            cardio: const CardioMetrics(deviceCalories: 612),
          ),
        ]);
        addTearDown(container.dispose);

        container.read(statMetricControllerProvider.notifier).select(StatMetric.activeCalories);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        final points = container.read(statChartDataProvider).value!;
        // 486, not 1098 and not 612.
        expect(_asPairs(points), [(_day(1), 486.0)]);
      },
    );

    test(
      'workoutMinutes: D-C3.3 — a cardio session reports moving time, not wall-clock',
      () async {
        final container = _buildContainer(sessions: [
          // 90 min wall-clock, but only 42 min actually moving (rest stops).
          _cardioSession(
            startedAt: _day(0).add(const Duration(hours: 8)),
            finishedAt: _day(0).add(const Duration(hours: 9, minutes: 30)),
            movingSeconds: 42 * 60,
          ),
        ]);
        addTearDown(container.dispose);

        container.read(statMetricControllerProvider.notifier).select(StatMetric.workoutMinutes);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        final points = container.read(statChartDataProvider).value!;
        expect(_asPairs(points), [(_day(0), 42.0)]);
      },
    );

    test('cardioSessions: counts only cardio sessions per day, strength excluded', () async {
      final container = _buildContainer(sessions: [
        _cardioSession(startedAt: _day(1).add(const Duration(hours: 7))),
        _cardioSession(startedAt: _day(1).add(const Duration(hours: 18))),
        _session(startedAt: _day(1).add(const Duration(hours: 12)), finishedAt: _day(1)), // strength
        _cardioSession(startedAt: _day(0).add(const Duration(hours: 7))),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.cardioSessions);
      await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

      final points = container.read(statChartDataProvider).value!;
      expect(_asPairs(points), [(_day(1), 2.0), (_day(0), 1.0)]);
    });

    test('cardioMovingMinutes: sums moving seconds (not gross duration) per day, cardio only',
        () async {
      final container = _buildContainer(sessions: [
        _cardioSession(startedAt: _day(0).add(const Duration(hours: 7)), movingSeconds: 1800),
        _cardioSession(startedAt: _day(0).add(const Duration(hours: 18)), movingSeconds: 600),
        // Strength session in the same day must not contribute.
        _session(startedAt: _day(0).add(const Duration(hours: 12)), finishedAt: _day(0)),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.cardioMovingMinutes);
      await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

      final points = container.read(statChartDataProvider).value!;
      expect(_asPairs(points), [(_day(0), 40.0)]); // (1800+600)/60
    });

    test('cardioDistance: sums km for DISTANCE and MACHINE families, skips GAME', () async {
      final container = _buildContainer(sessions: [
        _cardioSession(
          startedAt: _day(0).add(const Duration(hours: 7)),
          distanceMeters: 5000,
        ),
        _cardioSession(
          startedAt: _day(0).add(const Duration(hours: 12)),
          activityType: 'INDOOR_BIKE',
          distanceMeters: 15000,
        ),
        // GAME family — basketball has no meaningful "distance" metric here.
        _cardioSession(
          startedAt: _day(0).add(const Duration(hours: 18)),
          activityType: 'BASKETBALL',
          distanceMeters: 2000,
        ),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.cardioDistance);
      await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

      final points = container.read(statChartDataProvider).value!;
      expect(_asPairs(points), [(_day(0), 20.0)]); // (5000+15000)/1000, basketball excluded
    });

    test('cardioElevationGain: sums meters for DISTANCE only, MACHINE excluded', () async {
      final container = _buildContainer(sessions: [
        _cardioSession(
          startedAt: _day(0).add(const Duration(hours: 7)),
          activityType: 'HIKING',
          elevationGainMeters: 320,
        ),
        // Indoor bike: schema allows the column, but it's not real elevation.
        _cardioSession(
          startedAt: _day(0).add(const Duration(hours: 12)),
          activityType: 'INDOOR_BIKE',
          elevationGainMeters: 999,
        ),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.cardioElevationGain);
      await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

      final points = container.read(statChartDataProvider).value!;
      expect(_asPairs(points), [(_day(0), 320.0)]);
    });

    group('cardioAvgPace (D-C3.6)', () {
      test('is distance-weighted per day, not the arithmetic mean of each session\'s pace',
          () async {
        final container = _buildContainer(sessions: [
          // 1 km in 4 min (4 min/km) and 20 km in 100 min (5 min/km) — the
          // naive arithmetic mean of the two paces would be 4.5 min/km; the
          // correct Σtime/Σdistance weighted pace is 104/21 ≈ 4.952 min/km.
          _cardioSession(
            startedAt: _day(0).add(const Duration(hours: 7)),
            movingSeconds: 4 * 60,
            distanceMeters: 1000,
          ),
          _cardioSession(
            startedAt: _day(0).add(const Duration(hours: 12)),
            movingSeconds: 100 * 60,
            distanceMeters: 20000,
          ),
        ]);
        addTearDown(container.dispose);

        container.read(statMetricControllerProvider.notifier).select(StatMetric.cardioAvgPace);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        final points = container.read(statChartDataProvider).value!;
        expect(points, hasLength(1));
        expect(points.single.date, _day(0));
        expect(points.single.value, closeTo(104 / 21, 0.0001));
      });

      test('excludes hiking even though it is a DISTANCE-family activity', () async {
        final container = _buildContainer(sessions: [
          _cardioSession(
            startedAt: _day(0),
            activityType: 'HIKING',
            movingSeconds: 3600,
            distanceMeters: 5000,
          ),
        ]);
        addTearDown(container.dispose);

        container.read(statMetricControllerProvider.notifier).select(StatMetric.cardioAvgPace);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        expect(container.read(statChartDataProvider).value, isEmpty);
      });

      test('a day with only zero/missing distance is absent, not a divide-by-zero point',
          () async {
        final container = _buildContainer(sessions: [
          _cardioSession(startedAt: _day(0), movingSeconds: 600, distanceMeters: 0),
          _cardioSession(startedAt: _day(1), movingSeconds: 600), // no distance recorded at all
        ]);
        addTearDown(container.dispose);

        container.read(statMetricControllerProvider.notifier).select(StatMetric.cardioAvgPace);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        expect(container.read(statChartDataProvider).value, isEmpty);
      });
    });

    test('maxHeartRate: each day\'s point is that day\'s highest reading, not a sum/average',
        () async {
      final container = _buildContainer(sessions: [
        _cardioSession(startedAt: _day(0).add(const Duration(hours: 7)), maxHeartRate: 152),
        _cardioSession(startedAt: _day(0).add(const Duration(hours: 18)), maxHeartRate: 171),
        _cardioSession(startedAt: _day(1).add(const Duration(hours: 7)), maxHeartRate: 160),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.maxHeartRate);
      await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

      final points = container.read(statChartDataProvider).value!;
      expect(_asPairs(points), [(_day(1), 160.0), (_day(0), 171.0)]);
    });

    test(
        'cardioMaxAltitude (C8.7): each day\'s point is that day\'s highest peak, not a sum/average',
        () async {
      final container = _buildContainer(sessions: [
        _cardioSession(
            startedAt: _day(0).add(const Duration(hours: 7)),
            activityType: 'HIKING',
            maxAltitudeMeters: 612),
        _cardioSession(
            startedAt: _day(0).add(const Duration(hours: 18)),
            activityType: 'HIKING',
            maxAltitudeMeters: 756),
        _cardioSession(
            startedAt: _day(1).add(const Duration(hours: 7)),
            activityType: 'RUNNING',
            maxAltitudeMeters: 340),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.cardioMaxAltitude);
      await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

      final points = container.read(statChartDataProvider).value!;
      expect(_asPairs(points), [(_day(1), 340.0), (_day(0), 756.0)]);
    });

    test('cardioMaxAltitude ignores MACHINE/GAME sessions even with a value', () async {
      final container = _buildContainer(sessions: [
        _cardioSession(
            startedAt: _day(0), activityType: 'INDOOR_BIKE', maxAltitudeMeters: 5000),
      ]);
      addTearDown(container.dispose);

      container.read(statMetricControllerProvider.notifier).select(StatMetric.cardioMaxAltitude);
      await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

      expect(container.read(statChartDataProvider).value, isEmpty);
    });

    group('StatKindFilter (D-C3.4)', () {
      final mixedSessions = [
        _session(
          startedAt: _day(0).add(const Duration(hours: 8)),
          finishedAt: _day(0).add(const Duration(hours: 9)),
        ), // strength, 60 min
        _cardioSession(
          startedAt: _day(0).add(const Duration(hours: 18)),
          finishedAt: _day(0).add(const Duration(hours: 18, minutes: 30)),
          movingSeconds: 25 * 60,
        ), // cardio, 25 min moving
      ];

      test('all: workoutCount includes both kinds (unchanged default behaviour)', () async {
        final container = _buildContainer(sessions: mixedSessions);
        addTearDown(container.dispose);

        container.read(statMetricControllerProvider.notifier).select(StatMetric.workoutCount);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        expect(_asPairs(container.read(statChartDataProvider).value!), [(_day(0), 2.0)]);
      });

      test('strength: workoutCount/workoutMinutes only count the strength session', () async {
        final container = _buildContainer(sessions: mixedSessions);
        addTearDown(container.dispose);
        container.read(statKindFilterControllerProvider.notifier).select(StatKindFilter.strength);

        container.read(statMetricControllerProvider.notifier).select(StatMetric.workoutCount);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();
        expect(_asPairs(container.read(statChartDataProvider).value!), [(_day(0), 1.0)]);

        container.read(statMetricControllerProvider.notifier).select(StatMetric.workoutMinutes);
        expect(_asPairs(container.read(statChartDataProvider).value!), [(_day(0), 60.0)]);
      });

      test('cardio: workoutCount/workoutMinutes only count the cardio session', () async {
        final container = _buildContainer(sessions: mixedSessions);
        addTearDown(container.dispose);
        container.read(statKindFilterControllerProvider.notifier).select(StatKindFilter.cardio);

        container.read(statMetricControllerProvider.notifier).select(StatMetric.workoutCount);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();
        expect(_asPairs(container.read(statChartDataProvider).value!), [(_day(0), 1.0)]);

        container.read(statMetricControllerProvider.notifier).select(StatMetric.workoutMinutes);
        expect(_asPairs(container.read(statChartDataProvider).value!), [(_day(0), 25.0)]);
      });

      test('strength: a cardio-only metric shows nothing at all, even with cardio data present',
          () async {
        final container = _buildContainer(sessions: mixedSessions);
        addTearDown(container.dispose);
        container.read(statKindFilterControllerProvider.notifier).select(StatKindFilter.strength);

        container.read(statMetricControllerProvider.notifier).select(StatMetric.cardioMovingMinutes);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        expect(container.read(statChartDataProvider).value, isEmpty);
      });

      test('availableStatMetricsProvider: strength filter hides every cardio-only metric',
          () async {
        final container = _buildContainer(
          meals: [],
          sessions: mixedSessions,
          water: [],
          weights: [],
          steps: [],
        );
        addTearDown(container.dispose);
        container.read(statKindFilterControllerProvider.notifier).select(StatKindFilter.strength);

        await container.listen(mealControllerProvider.future, (previous, next) {}).read();
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();
        await container.listen(allWaterEntriesProvider.future, (previous, next) {}).read();
        await container.listen(weightControllerProvider.future, (previous, next) {}).read();
        await container.listen(allStepCountsProvider.future, (previous, next) {}).read();

        expect(container.read(availableStatMetricsProvider), {
          StatMetric.workoutCount,
          StatMetric.workoutMinutes,
        });
      });
    });

    // -- Time at threshold+ (C9.5) ----------------------------------------

    group('cardioHardZoneMinutes', () {
      test('sums zone 4+5 minutes per day, across every cardio family', () async {
        final container = _buildContainer(sessions: [
          // A run: 9 min at Z4, 3 at Z5 => 12.
          _cardioSession(
            startedAt: _day(1).add(const Duration(hours: 7)),
            finishedAt: _day(1).add(const Duration(hours: 8)),
            zoneSeconds: const [600, 1200, 900, 540, 180],
          ),
          // A match on the same day: 10 min at Z4, 5 at Z5 => 15. Zones are
          // where a GAME session finally contributes to the statistics.
          _cardioSession(
            startedAt: _day(1).add(const Duration(hours: 19)),
            finishedAt: _day(1).add(const Duration(hours: 20)),
            activityType: 'BASKETBALL',
            zoneSeconds: const [300, 900, 900, 600, 300],
          ),
        ]);
        addTearDown(container.dispose);

        container
            .read(statMetricControllerProvider.notifier)
            .select(StatMetric.cardioHardZoneMinutes);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        expect(_asPairs(container.read(statChartDataProvider).value!), [(_day(1), 27.0)]);
      });

      test('a session with no zone data is absent, but a genuine zero is charted', () async {
        final container = _buildContainer(sessions: [
          // No zones at all: contributes nothing, not a zero.
          _cardioSession(
            startedAt: _day(2).add(const Duration(hours: 7)),
            finishedAt: _day(2).add(const Duration(hours: 8)),
            distanceMeters: 5000,
          ),
          // Zones measured, none of them hard: zero is the honest answer.
          _cardioSession(
            startedAt: _day(1).add(const Duration(hours: 7)),
            finishedAt: _day(1).add(const Duration(hours: 8)),
            zoneSeconds: const [1800, 1800, null, null, null],
          ),
        ]);
        addTearDown(container.dispose);

        container
            .read(statMetricControllerProvider.notifier)
            .select(StatMetric.cardioHardZoneMinutes);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        expect(_asPairs(container.read(statChartDataProvider).value!), [(_day(1), 0.0)]);
      });

      test('an inconsistent row cannot inflate a day beyond the session length', () async {
        // The docs/cardio/60 §9 case: the watch and the phone both wrote
        // zones, so the five total 90 minutes on a 60 minute session. Read
        // through HrZoneBreakdown, the sum is capped rather than charted.
        final container = _buildContainer(sessions: [
          _cardioSession(
            startedAt: _day(1).add(const Duration(hours: 7)),
            finishedAt: _day(1).add(const Duration(hours: 8)), // 60 min
            zoneSeconds: const [1200, 1200, 1200, 1200, 600],
          ),
        ]);
        addTearDown(container.dispose);

        container
            .read(statMetricControllerProvider.notifier)
            .select(StatMetric.cardioHardZoneMinutes);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        final value = container.read(statChartDataProvider).value!.single.value;
        expect(value, lessThanOrEqualTo(60.0));
      });

      test('the strength filter hides it entirely', () async {
        final container = _buildContainer(sessions: [
          _cardioSession(
            startedAt: _day(1).add(const Duration(hours: 7)),
            finishedAt: _day(1).add(const Duration(hours: 8)),
            zoneSeconds: const [600, 600, 600, 600, 600],
          ),
        ]);
        addTearDown(container.dispose);

        container
            .read(statMetricControllerProvider.notifier)
            .select(StatMetric.cardioHardZoneMinutes);
        container.read(statKindFilterControllerProvider.notifier).select(StatKindFilter.strength);
        await container.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();

        expect(container.read(statChartDataProvider).value, isEmpty);
      });

      test('is offered only once some session actually carries zone data', () async {
        // `availableStatMetricsProvider` watches every source, so all five
        // have to resolve before it can be read — same shape as the strength-
        // filter availability test above.
        Future<Set<StatMetric>> availableWith(WorkoutSession session) async {
          final container = _buildContainer(
            meals: [],
            sessions: [session],
            water: [],
            weights: [],
            steps: [],
          );
          addTearDown(container.dispose);
          await container.listen(mealControllerProvider.future, (previous, next) {}).read();
          await container
              .listen(workoutSessionControllerProvider.future, (previous, next) {})
              .read();
          await container.listen(allWaterEntriesProvider.future, (previous, next) {}).read();
          await container.listen(weightControllerProvider.future, (previous, next) {}).read();
          await container.listen(allStepCountsProvider.future, (previous, next) {}).read();
          return container.read(availableStatMetricsProvider);
        }

        expect(
          await availableWith(_cardioSession(
            startedAt: _day(1).add(const Duration(hours: 7)),
            finishedAt: _day(1).add(const Duration(hours: 8)),
            distanceMeters: 5000,
          )),
          isNot(contains(StatMetric.cardioHardZoneMinutes)),
        );
        expect(
          await availableWith(_cardioSession(
            startedAt: _day(1).add(const Duration(hours: 7)),
            finishedAt: _day(1).add(const Duration(hours: 8)),
            zoneSeconds: const [600, null, null, null, null],
          )),
          contains(StatMetric.cardioHardZoneMinutes),
        );
      });
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

    test('cardio metrics only appear once a session actually has the value each one needs',
        () async {
      final container = _buildContainer(
        meals: [],
        sessions: [
          // Distance + moving time + heart rate, but no elevation.
          _cardioSession(
            startedAt: _day(0),
            movingSeconds: 1800,
            distanceMeters: 5000,
            maxHeartRate: 150,
          ),
        ],
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

      expect(container.read(availableStatMetricsProvider), {
        StatMetric.workoutCount,
        StatMetric.cardioSessions,
        StatMetric.cardioMovingMinutes,
        StatMetric.cardioDistance,
        StatMetric.cardioAvgPace,
        StatMetric.maxHeartRate,
        // Not workoutMinutes: the session never finished. Not
        // cardioElevationGain: no elevationGainMeters was set. Not
        // cardioMaxAltitude either, for the same reason (C8.7).
      });
    });

    test('cardioMaxAltitude appears only once a DISTANCE session has a value (C8.7)', () async {
      final container = _buildContainer(
        meals: [],
        sessions: [
          _cardioSession(
            startedAt: _day(0),
            activityType: 'INDOOR_BIKE',
            maxAltitudeMeters: 5000, // MACHINE — doesn't count
          ),
        ],
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

      expect(
        container.read(availableStatMetricsProvider).contains(StatMetric.cardioMaxAltitude),
        isFalse,
      );

      final withHike = _buildContainer(
        meals: [],
        sessions: [
          _cardioSession(startedAt: _day(0), activityType: 'HIKING', maxAltitudeMeters: 756),
        ],
        water: [],
        weights: [],
        steps: [],
      );
      addTearDown(withHike.dispose);
      await withHike.listen(mealControllerProvider.future, (previous, next) {}).read();
      await withHike.listen(workoutSessionControllerProvider.future, (previous, next) {}).read();
      await withHike.listen(allWaterEntriesProvider.future, (previous, next) {}).read();
      await withHike.listen(weightControllerProvider.future, (previous, next) {}).read();
      await withHike.listen(allStepCountsProvider.future, (previous, next) {}).read();

      expect(
        withHike.read(availableStatMetricsProvider).contains(StatMetric.cardioMaxAltitude),
        isTrue,
      );
    });
  });
}
