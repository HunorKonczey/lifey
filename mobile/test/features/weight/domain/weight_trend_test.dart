import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/weight/domain/weight_trend.dart';
import 'package:lifey/shared/widgets/charts/time_series_chart.dart';

/// docs/76-smarter-weight-trend-plan.md — the window rule, the two-entry rule,
/// and every state the goal card can be in.

final _day0 = DateTime(2026, 3, 1);

TimeSeriesPoint _p(int dayOffset, double value) =>
    TimeSeriesPoint(date: _day0.add(Duration(days: dayOffset)), value: value);

/// A straight line of daily weigh-ins, [kgPerDay] apart.
List<TimeSeriesPoint> _daily(int days, {double from = 90, double kgPerDay = 0}) =>
    [for (var i = 0; i < days; i++) _p(i, from + kgPerDay * i)];

void main() {
  group('movingAverage', () {
    test('averages the trailing 7 days, not the trailing 7 entries', () {
      // Two entries three weeks apart: the later one has an empty window
      // behind it, so averaging "the last two" would smear across 21 days.
      final points = [_p(0, 100), _p(21, 90)];

      expect(movingAverage(points), [null, null]);
    });

    test('a window with a single entry has nothing to average', () {
      expect(movingAverage([_p(0, 80)]), [null]);
    });

    test('smooths a daily series over its window', () {
      final trend = movingAverage([_p(0, 80), _p(1, 82), _p(2, 81)]);

      expect(trend[0], isNull);
      expect(trend[1], 81);
      expect(trend[2], closeTo(81, 0.001));
    });

    test('drops entries as they fall out of the window', () {
      final points = _daily(10, from: 80, kgPerDay: 1);

      final trend = movingAverage(points);

      // Day 9 averages days 3..9 only — 83..89.
      expect(trend.last, closeTo(86, 0.001));
    });

    test('a gap breaks the trend rather than bridging it', () {
      final points = [_p(0, 80), _p(1, 81), _p(30, 78), _p(31, 77)];

      final trend = movingAverage(points);

      expect(trend[1], isNotNull);
      expect(trend[2], isNull, reason: 'first day after the gap stands alone');
      expect(trend[3], isNotNull);
    });
  });

  group('projectGoal', () {
    WeightProjection? project(List<TimeSeriesPoint> points, double goal) => projectGoal(
          points: points,
          trend: movingAverage(points),
          goalKg: goal,
          now: _day0.add(const Duration(days: 40)),
        );

    test('names a date when the trend moves toward the goal', () {
      // 100 g/day down for 30 days, goal 5 kg below the current trend.
      final projection = project(_daily(30, from: 90, kgPerDay: -0.1), 82)!;

      expect(projection.state, WeightProjectionState.onTrack);
      // Slightly flatter than the raw 0.7 kg/week: the first trend values
      // average a partial window, which is the smoothing doing its job.
      expect(projection.kgPerWeek, closeTo(-0.7, 0.05));
      // The trend trails the raw line by about three days of loss, so there
      // is a little more to go than the last weigh-in suggests: 87.4 - 82.
      expect(projection.remainingKg, closeTo(5.4, 0.1));
      expect(projection.currentKg - projection.goalKg, closeTo(projection.remainingKg, 0.001));
      // 5.4 kg left at ~0.1 kg/day.
      expect(projection.etaDate!.difference(_day0.add(const Duration(days: 40))).inDays,
          closeTo(56, 5));
    });

    test('reads the trend, not the last noisy weigh-in', () {
      final points = [..._daily(29, from: 90, kgPerDay: -0.1), _p(29, 95)];

      final projection = project(points, 80)!;

      // The raw series ends at 95 kg and the trend behind it around 87.5;
      // one heavy morning may move the trend by a fraction of a kilo, never
      // by the 5 kg it moved the scale.
      expect(projection.currentKg, lessThan(89));
      expect(projection.currentKg, greaterThan(87));
    });

    test('says so instead of guessing from a fortnight of nothing', () {
      final projection = project(_daily(6, from: 90, kgPerDay: -0.1), 80)!;

      expect(projection.state, WeightProjectionState.notEnoughData);
      expect(projection.kgPerWeek, isNull);
    });

    test('flags a trend moving away from the goal', () {
      final projection = project(_daily(30, from: 90, kgPerDay: 0.1), 80)!;

      expect(projection.state, WeightProjectionState.wrongWay);
      expect(projection.kgPerWeek, closeTo(0.7, 0.05));
      expect(projection.etaDate, isNull);
    });

    test('a flat trend is not a slow one — it never arrives', () {
      final projection = project(_daily(30, from: 90), 80)!;

      expect(projection.state, WeightProjectionState.wrongWay);
    });

    test('refuses an estimate further out than two years', () {
      // 1 g/day against a 10 kg gap — ~27 years.
      final projection = project(_daily(30, from: 90, kgPerDay: -0.001), 80)!;

      expect(projection.state, WeightProjectionState.tooSlow);
      expect(projection.etaDate, isNull);
    });

    test('recognizes the goal as reached within the tolerance', () {
      final projection = project(_daily(30, from: 80.1, kgPerDay: 0), 80)!;

      expect(projection.state, WeightProjectionState.reached);
      expect(projection.remainingKg, lessThanOrEqualTo(goalReachedToleranceKg));
    });

    test('gaining toward a higher goal counts as on track', () {
      final projection = project(_daily(30, from: 60, kgPerDay: 0.05), 65)!;

      expect(projection.state, WeightProjectionState.onTrack);
      expect(projection.kgPerWeek, greaterThan(0));
    });

    test('nothing to project from yields null', () {
      expect(projectGoal(points: const [], trend: const [], goalKg: 80), isNull);
      expect(project([_p(0, 90)], 80), isNull, reason: 'no trend value yet');
    });
  });
}
