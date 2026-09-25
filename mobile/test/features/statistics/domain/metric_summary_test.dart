import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/statistics/domain/metric_summary.dart';
import 'package:lifey/features/statistics/domain/stat_metric.dart';
import 'package:lifey/shared/widgets/charts/time_series_chart.dart';

/// R4.5: what each metric says about a range — hero, trend against the period
/// before, side stats — as a pure function.

final _today = DateTime(2026, 9, 24); // a Thursday

DateTime _d(int daysAgo) => DateTime(_today.year, _today.month, _today.day - daysAgo);

/// Points oldest first from (daysAgo, value) pairs.
/// Session values, each on its own recent day.
List<TimeSeriesPoint> _samples(List<double> values) =>
    [for (final (i, v) in values.indexed) TimeSeriesPoint(date: _d(i), value: v)];

StatSeries _series(List<(int, double)> pairs, {List<double> samples = const [], Map<DateTime, double> weights = const {}}) {
  final sorted = [...pairs]..sort((a, b) => b.$1.compareTo(a.$1));
  return StatSeries(
    points: [for (final (ago, v) in sorted) TimeSeriesPoint(date: _d(ago), value: v)],
    samples: _samples(samples),
    weights: weights,
  );
}

StatSide _side(MetricSummary s, StatSideKind kind) => s.sides.singleWhere((e) => e.kind == kind);

bool _has(MetricSummary s, StatSideKind kind) => s.sides.any((e) => e.kind == kind);

void main() {
  group('daily totals leave today out (an unfinished day understates)', () {
    test('steps: average, lowest, highest, total over the complete days', () {
      final s = summaryFor(
        StatMetric.steps,
        current: _series([(3, 8000), (2, 12000), (1, 4000), (0, 300)]),
        today: _today,
        rangeDays: 30,
      );

      expect(s.heroKind, StatHeroKind.dailyAverage);
      expect(s.hero, 8000); // (8000 + 12000 + 4000) / 3, today's 300 left out
      expect(_side(s, StatSideKind.lowest).value, 4000);
      expect(_side(s, StatSideKind.highest).value, 12000);
      expect(_side(s, StatSideKind.total).value, 24000);
      expect(s.chartKind, StatChartKind.line);
    });

    test('only today has data: it is used rather than showing nothing', () {
      final s = summaryFor(StatMetric.steps, current: _series([(0, 900)]), today: _today, rangeDays: 7);

      expect(s.hero, 900);
    });

    test('an empty range has no hero and no sides', () {
      final s = summaryFor(StatMetric.steps, current: StatSeries.empty, today: _today, rangeDays: 7);

      expect(s.hero, isNull);
      expect(s.sides, isEmpty);
      expect(s.trend, isNull);
    });
  });

  group('nutrition and water', () {
    final days = _series([(4, 2300), (3, 2500), (2, 2000), (1, 2700), (0, 400)]);

    test('calories: average, lowest, highest, days on target (within 10 % of the goal)', () {
      final s = summaryFor(
        StatMetric.calories,
        current: days,
        today: _today,
        rangeDays: 30,
        goals: const StatGoals(calories: 2400),
      );

      expect(s.hero, (2300 + 2500 + 2000 + 2700) / 4);
      expect(_side(s, StatSideKind.lowest).value, 2000);
      expect(_side(s, StatSideKind.highest).value, 2700);
      // 2160..2640: 2300 and 2500 are in, 2000 and 2700 are not
      expect(_side(s, StatSideKind.daysOnTarget).value, 2);
      expect(s.chartKind, StatChartKind.dailyBars);
    });

    test('protein: days at or above the goal', () {
      final s = summaryFor(
        StatMetric.protein,
        current: _series([(3, 100), (2, 130), (1, 129)]),
        today: _today,
        rangeDays: 30,
        goals: const StatGoals(protein: 129),
      );

      expect(_side(s, StatSideKind.daysAtGoal).value, 2); // 130 and 129
    });

    test('water: days at or above the goal, in litres', () {
      final s = summaryFor(
        StatMetric.water,
        current: _series([(2, 2.7), (1, 1.5)]),
        today: _today,
        rangeDays: 7,
        goals: const StatGoals(waterLiters: 2.6),
      );

      expect(_side(s, StatSideKind.daysAtGoal).value, 1);
      expect(s.hero, closeTo(2.1, 1e-9));
    });

    test('no goal set: the third stat is left out, not zero', () {
      final s = summaryFor(StatMetric.calories, current: days, today: _today, rangeDays: 30);

      expect(s.sides.map((e) => e.kind), [StatSideKind.lowest, StatSideKind.highest]);
    });
  });

  group('weight', () {
    final series = _series([(20, 66.0), (10, 65.4), (3, 64.9), (0, 64.5)]);

    test('latest as the hero, and no total anywhere', () {
      final s = summaryFor(StatMetric.weight, current: series, today: _today, rangeDays: 30);

      expect(s.heroKind, StatHeroKind.latest);
      expect(s.hero, 64.5);
      expect(s.sides.map((e) => e.kind), [StatSideKind.lowest, StatSideKind.highest, StatSideKind.changeInPeriod]);
      expect(_has(s, StatSideKind.total), isFalse);
      expect(_side(s, StatSideKind.lowest).value, 64.5);
      expect(_side(s, StatSideKind.highest).value, 66.0);
      expect(_side(s, StatSideKind.changeInPeriod).value, closeTo(-1.5, 1e-9));
      expect(_side(s, StatSideKind.changeInPeriod).valueKind, StatValueKind.signedMetric);
    });

    test('the trend is the latest against the latest of the period before, in kg — no percent', () {
      final s = summaryFor(
        StatMetric.weight,
        current: series,
        prior: _series([(50, 67.0), (40, 66.4)]),
        today: _today,
        rangeDays: 30,
      );

      expect(s.trend!.delta, closeTo(64.5 - 66.4, 1e-9));
      expect(s.trend!.percent, isNull);
    });
  });

  group('workouts', () {
    // Mon 21 Sep .. Thu 24 Sep are this week's; Sep 14-20 the week before
    final points = _series([(10, 1), (9, 1), (7, 1), (3, 2), (2, 1), (0, 1)]);
    final samples = <double>[50, 45, 60, 40, 72, 30, 55, 20];

    test('count with the weekly rate, the busiest week, the longest and the total time', () {
      final s = summaryFor(StatMetric.workoutCount, current: points, today: _today, rangeDays: 30, goals: StatGoals.none);
      // add samples through a series that carries them
      final withSamples = summaryFor(
        StatMetric.workoutCount,
        current: StatSeries(points: points.points, samples: _samples(samples)),
        today: _today,
        rangeDays: 30,
      );

      expect(s.heroKind, StatHeroKind.count);
      expect(s.hero, 7); // 1+1+1+2+1+1
      expect(s.perWeek, closeTo(7 / (30 / 7), 1e-9));
      expect(s.chartKind, StatChartKind.weeklyBars);
      expect(_side(s, StatSideKind.mostInAWeek).value, 4); // this week: 2 + 1 + 1
      expect(_has(s, StatSideKind.longest), isFalse); // no per-session values: not invented
      expect(_side(withSamples, StatSideKind.longest).value, 72);
      expect(_side(withSamples, StatSideKind.totalTime).value, 372);
    });

    test('minutes: total, average per workout, longest, per week', () {
      final s = summaryFor(
        StatMetric.workoutMinutes,
        current: StatSeries(points: _series([(3, 90), (0, 60)]).points, samples: _samples(const [50, 40, 60])),
        today: _today,
        rangeDays: 28,
      );

      expect(s.hero, 150);
      expect(_side(s, StatSideKind.avgPerWorkout).value, 50);
      expect(_side(s, StatSideKind.longest).value, 60);
      expect(_side(s, StatSideKind.perWeek).value, closeTo(150 / 4, 1e-9));
    });

    test('a workout today counts (it already happened)', () {
      final s = summaryFor(StatMetric.workoutCount, current: _series([(0, 1)]), today: _today, rangeDays: 7);

      expect(s.hero, 1);
    });

    test('most in a week counts calendar weeks, Monday to Sunday', () {
      // Sun 20 Sep (3), Mon 21 Sep (2) — two different weeks, not five in a row
      final s = summaryFor(StatMetric.workoutCount, current: _series([(4, 3), (3, 2)]), today: _today, rangeDays: 30);

      expect(_side(s, StatSideKind.mostInAWeek).value, 3);
    });
  });

  group('cardio', () {
    test('sessions: count, per week, most in a week', () {
      final s = summaryFor(StatMetric.cardioSessions, current: _series([(9, 1), (8, 1), (2, 1)]), today: _today, rangeDays: 28);

      expect(s.hero, 3);
      expect(_side(s, StatSideKind.perWeek).value, closeTo(3 / 4, 1e-9));
      expect(s.perWeek, closeTo(3 / 4, 1e-9));
      expect(_side(s, StatSideKind.mostInAWeek).value, 2);
    });

    test('distance: total km, the longest and the average per session', () {
      final s = summaryFor(
        StatMetric.cardioDistance,
        current: StatSeries(points: _series([(5, 10), (2, 5.2)]).points, samples: _samples(const [10, 3.2, 2])),
        today: _today,
        rangeDays: 30,
      );

      expect(s.hero, closeTo(15.2, 1e-9));
      expect(_side(s, StatSideKind.longest).value, 10);
      expect(_side(s, StatSideKind.avgPerSession).value, closeTo(5.0666666, 1e-6));
      expect(_side(s, StatSideKind.longest).valueKind, StatValueKind.distance);
    });

    test('moving minutes: total and the same two', () {
      final s = summaryFor(
        StatMetric.cardioMovingMinutes,
        current: StatSeries(points: _series([(5, 60), (2, 30)]).points, samples: _samples(const [60, 20, 10])),
        today: _today,
        rangeDays: 30,
      );

      expect(s.hero, 90);
      expect(_side(s, StatSideKind.longest).value, 60);
      expect(_side(s, StatSideKind.avgPerSession).value, 30);
    });

    test('elevation: the total and the highest session', () {
      final s = summaryFor(
        StatMetric.cardioElevationGain,
        current: StatSeries(points: _series([(5, 300), (2, 120)]).points, samples: _samples(const [300, 80, 40])),
        today: _today,
        rangeDays: 30,
      );

      expect(s.hero, 420);
      expect(s.sides.map((e) => e.kind), [StatSideKind.highestSession]);
      expect(_side(s, StatSideKind.highestSession).value, 300);
    });

    test('pace: weighted by distance — a 1 km jog and a 20 km run are not equals', () {
      // day A: 1 km at 6:00/km, day B: 20 km at 5:00/km → Σ time / Σ km = (6 + 100) / 21
      final a = _d(5);
      final b = _d(2);
      final s = summaryFor(
        StatMetric.cardioAvgPace,
        current: StatSeries(
          points: [TimeSeriesPoint(date: a, value: 6.0), TimeSeriesPoint(date: b, value: 5.0)],
          weights: {a: 1, b: 20},
        ),
        today: _today,
        rangeDays: 30,
      );

      expect(s.heroKind, StatHeroKind.weightedPace);
      expect(s.hero, closeTo(106 / 21, 1e-9));
      expect(_side(s, StatSideKind.fastest).value, 5.0);
      expect(_side(s, StatSideKind.slowest).value, 6.0);
      expect(s.chartKind, StatChartKind.line);
    });

    test('max heart rate: the highest, and the average of the daily maxima', () {
      final s = summaryFor(StatMetric.maxHeartRate, current: _series([(6, 170), (3, 182), (1, 176)]), today: _today, rangeDays: 30);

      expect(s.hero, 182);
      expect(s.heroKind, StatHeroKind.highest);
      expect(_side(s, StatSideKind.averageOfMaxima).value, closeTo(176, 1e-9));
    });

    test('highest altitude: just the peak, no side stats', () {
      final s = summaryFor(StatMetric.cardioMaxAltitude, current: _series([(6, 750), (3, 1200)]), today: _today, rangeDays: 30);

      expect(s.hero, 1200);
      expect(s.sides, isEmpty);
    });

    test('hard-zone minutes: total and per week', () {
      final s = summaryFor(StatMetric.cardioHardZoneMinutes, current: _series([(6, 12), (3, 20)]), today: _today, rangeDays: 28);

      expect(s.hero, 32);
      expect(_side(s, StatSideKind.perWeek).value, closeTo(8, 1e-9));
    });

    test('active calories: the daily average, the highest day, the total', () {
      final s = summaryFor(StatMetric.activeCalories, current: _series([(3, 300), (2, 500), (0, 50)]), today: _today, rangeDays: 30);

      expect(s.hero, 400); // today's 50 left out
      expect(_side(s, StatSideKind.highest).value, 500);
      expect(_side(s, StatSideKind.total).value, 800);
    });
  });

  group('trend against the period before', () {
    final current = _series([(3, 9000), (2, 9000), (1, 9000), (0, 100)]);

    test('the percent change of the daily average', () {
      final s = summaryFor(StatMetric.steps, current: current, prior: _series([(40, 10000), (35, 10000)]), today: _today, rangeDays: 30);

      expect(s.trend!.percent, closeTo(-10, 1e-9));
      expect(s.trend!.delta, closeTo(-1000, 1e-9));
    });

    test('a prior period of 0 hides the percent — never ∞', () {
      final s = summaryFor(
        StatMetric.workoutCount,
        current: _series([(3, 1), (1, 1)]),
        prior: _series([(40, 0)]),
        today: _today,
        rangeDays: 30,
      );

      expect(s.trend, isNotNull);
      expect(s.trend!.delta, 2);
      expect(s.trend!.percent, isNull);
    });

    test('no prior period (range "all", or cut by the history window): no trend', () {
      final s = summaryFor(StatMetric.steps, current: current, today: _today);

      expect(s.trend, isNull);
    });

    test('a prior period with no data at all: no trend', () {
      final s = summaryFor(StatMetric.steps, current: current, prior: StatSeries.empty, today: _today, rangeDays: 30);

      expect(s.trend, isNull);
    });

    test('counts compare as a difference: +4 vs the prior period', () {
      final s = summaryFor(
        StatMetric.workoutCount,
        current: _series([(3, 5), (1, 5), (0, 8)]),
        prior: _series([(40, 7), (35, 7)]),
        today: _today,
        rangeDays: 30,
      );

      expect(s.hero, 18);
      expect(s.trend!.delta, 4);
    });

    test('pace: the trend compares the weighted paces', () {
      final a = _d(5);
      final p = _d(40);
      final s = summaryFor(
        StatMetric.cardioAvgPace,
        current: StatSeries(points: [TimeSeriesPoint(date: a, value: 5.0)], weights: {a: 10}),
        prior: StatSeries(points: [TimeSeriesPoint(date: p, value: 6.0)], weights: {p: 10}),
        today: _today,
        rangeDays: 30,
      );

      expect(s.trend!.delta, closeTo(-1, 1e-9)); // a minute per km faster
      expect(s.trend!.percent, closeTo(-1 / 6 * 100, 1e-9));
    });
  });

  group('weeklySums', () {
    test('calendar weeks Monday to Sunday, the empty ones as zero, the ends whole', () {
      // Thu 24 Sep; range from Wed 2 Sep: weeks of Aug 31, Sep 7, Sep 14, Sep 21
      final points = [
        TimeSeriesPoint(date: DateTime(2026, 9, 2), value: 1), // week of Aug 31
        TimeSeriesPoint(date: DateTime(2026, 9, 3), value: 2), // week of Aug 31
        TimeSeriesPoint(date: DateTime(2026, 9, 21), value: 4), // this week
        TimeSeriesPoint(date: DateTime(2026, 9, 24), value: 1), // this week
      ];

      final weeks = weeklySums(points, from: DateTime(2026, 9, 2), to: DateTime(2026, 9, 24));

      expect(weeks.map((w) => w.weekStart), [
        DateTime(2026, 8, 31),
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 21),
      ]);
      expect(weeks.map((w) => w.value), [3, 0, 0, 5]);
    });

    test('a 30-day range is five bars, not thirty', () {
      final weeks = weeklySums(const [], from: _d(29), to: _today);

      expect(weeks.length, inInclusiveRange(5, 6));
    });

    test('weekStart is a Monday, across a month and a year end', () {
      expect(weekStart(DateTime(2026, 9, 24)), DateTime(2026, 9, 21));
      expect(weekStart(DateTime(2026, 9, 21)), DateTime(2026, 9, 21));
      expect(weekStart(DateTime(2026, 9, 20)), DateTime(2026, 9, 14));
      expect(weekStart(DateTime(2026, 1, 1)), DateTime(2025, 12, 29));
    });
  });

  test('every metric has a chart kind and a summary (nothing falls through)', () {
    for (final metric in StatMetric.values) {
      chartKindFor(metric);
      final s = summaryFor(metric, current: _series([(2, 5), (1, 6)]), today: _today, rangeDays: 30);
      expect(s.hero, isNotNull, reason: metric.name);
      expect(s.sides.length, lessThanOrEqualTo(3), reason: metric.name);
    }
  });
}
