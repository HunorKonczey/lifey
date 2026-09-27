import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/weight/application/weight_headline.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';

final _now = DateTime(2026, 9, 24, 8);

WeightEntry _e(int daysAgo, double kg, {int hour = 7}) {
  final day = DateTime(2026, 9, 24).subtract(Duration(days: daysAgo));
  return WeightEntry(
    clientId: 'w$daysAgo-$hour',
    date: day,
    weight: kg,
    recordedAt: day.add(Duration(hours: hour)),
  );
}

/// Newest first, like `WeightRepository.watchAll`.
List<WeightEntry> _newestFirst(List<WeightEntry> entries) =>
    [...entries]..sort((a, b) => b.date != a.date ? b.date.compareTo(a.date) : b.recordedAt.compareTo(a.recordedAt));

void main() {
  test('nothing recorded, no headline', () {
    expect(computeWeightHeadline(const [], now: _now), isNull);
  });

  test('a single entry: no deltas, start = latest', () {
    final h = computeWeightHeadline([_e(0, 64.5)], now: _now)!;

    expect(h.latest.weight, 64.5);
    expect(h.latestIsToday, isTrue);
    expect(h.sinceLastKg, isNull);
    expect(h.change30dKg, isNull);
    expect(h.startKg, 64.5);
  });

  test('the canvas: 64.5 today after 64.6, down 1.4 over 30 days', () {
    final entries = _newestFirst([_e(30, 65.9), _e(20, 65.4), _e(1, 64.6), _e(0, 64.5)]);

    final h = computeWeightHeadline(entries, now: _now)!;

    expect(h.sinceLastKg, closeTo(-0.1, 1e-9));
    expect(h.change30dKg, closeTo(-1.4, 1e-9));
  });

  test('two weigh-ins on one day: the later recording is the day', () {
    final entries = _newestFirst([_e(1, 64.6), _e(0, 64.7, hour: 6), _e(0, 64.5, hour: 20)]);

    final h = computeWeightHeadline(entries, now: _now)!;

    expect(h.latest.weight, 64.5);
    expect(h.sinceLastKg, closeTo(-0.1, 1e-9)); // against the previous *day*
  });

  test('the latest entry is not today: not flagged as today', () {
    final h = computeWeightHeadline(_newestFirst([_e(3, 65), _e(2, 64.8)]), now: _now)!;

    expect(h.latestIsToday, isFalse);
  });

  test('a week of history is too short to call a 30-day change', () {
    final h = computeWeightHeadline(_newestFirst([_e(5, 65), _e(0, 64.5)]), now: _now)!;

    expect(h.change30dKg, isNull);
    expect(h.sinceLastKg, closeTo(-0.5, 1e-9));
  });

  test('entries older than 30 days do not count towards the 30-day change', () {
    final entries = _newestFirst([_e(90, 70), _e(31, 68), _e(10, 65), _e(0, 64.5)]);

    expect(computeWeightHeadline(entries, now: _now)!.change30dKg, closeTo(-0.5, 1e-9));
  });

  group('goal', () {
    final entries = _newestFirst([_e(60, 67.9), _e(0, 64.5)]);

    test('no goal: no progress, nothing remaining', () {
      final h = computeWeightHeadline(entries, now: _now)!;

      expect(h.hasGoal, isFalse);
      expect(h.progress, isNull);
      expect(h.remainingKg, isNull);
      expect(h.reached, isFalse);
    });

    test('start 67.9, now 64.5, goal 62.0: 2.5 to go, 58 % of the way', () {
      final h = computeWeightHeadline(entries, now: _now, goalKg: 62)!;

      expect(h.startKg, 67.9);
      expect(h.remainingKg, closeTo(2.5, 1e-9));
      expect(h.progress, closeTo(3.4 / 5.9, 1e-9));
      expect(h.goalIsLoss, isTrue);
      expect(h.reached, isFalse);
    });

    test('passed the goal: reached, the bar is full, not over-full', () {
      final h = computeWeightHeadline(_newestFirst([_e(60, 67.9), _e(0, 61.5)]), now: _now, goalKg: 62)!;

      expect(h.reached, isTrue);
      expect(h.progress, 1);
    });

    test('within 0.2 kg counts as reached', () {
      final h = computeWeightHeadline(_newestFirst([_e(60, 67.9), _e(0, 62.15)]), now: _now, goalKg: 62)!;

      expect(h.reached, isTrue);
    });

    test('gaining: the journey runs the other way', () {
      final h = computeWeightHeadline(_newestFirst([_e(60, 60), _e(0, 62)]), now: _now, goalKg: 66)!;

      expect(h.goalIsLoss, isFalse);
      expect(h.progress, closeTo(2 / 6, 1e-9));
      expect(h.reached, isFalse);
    });

    test('drifting away from the goal never goes below 0 %', () {
      final h = computeWeightHeadline(_newestFirst([_e(60, 65), _e(0, 66)]), now: _now, goalKg: 62)!;

      expect(h.progress, 0);
    });

    test('a goal equal to the start has no journey: full', () {
      final h = computeWeightHeadline(_newestFirst([_e(0, 62)]), now: _now, goalKg: 62)!;

      expect(h.progress, 1);
      expect(h.reached, isTrue);
    });
  });
}
