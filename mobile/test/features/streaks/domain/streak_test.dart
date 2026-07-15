import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/streaks/domain/streak.dart';

void main() {
  final today = DateTime(2026, 7, 15);

  DateTime daysBefore(int n) => today.subtract(Duration(days: n));

  test('empty history and today unmet -> current and best are zero', () {
    final streak = Streak.compute(
      metric: StreakMetric.water,
      metDays: const {},
      todayMet: false,
      today: today,
    );

    expect(streak.current, 0);
    expect(streak.best, 0);
    expect(streak.isActive, isFalse);
  });

  test('only today met -> current and best are 1', () {
    final streak = Streak.compute(
      metric: StreakMetric.water,
      metDays: const {},
      todayMet: true,
      today: today,
    );

    expect(streak.current, 1);
    expect(streak.best, 1);
    expect(streak.isActive, isTrue);
  });

  test('only yesterday met, today not yet met -> current is 1, does not break', () {
    final streak = Streak.compute(
      metric: StreakMetric.steps,
      metDays: {daysBefore(1)},
      todayMet: false,
      today: today,
    );

    expect(streak.current, 1);
    expect(streak.best, 1);
  });

  test('today met extends an existing run by one', () {
    final streak = Streak.compute(
      metric: StreakMetric.calories,
      metDays: {daysBefore(1), daysBefore(2), daysBefore(3)},
      todayMet: true,
      today: today,
    );

    expect(streak.current, 4);
    expect(streak.best, 4);
  });

  test('a gap before yesterday resets the current streak to just today', () {
    final streak = Streak.compute(
      metric: StreakMetric.calories,
      // day-1 (yesterday) is missing, so the run from today doesn't reach
      // the older days at all, even though day-2/day-3 are consecutive.
      metDays: {daysBefore(2), daysBefore(3)},
      todayMet: true,
      today: today,
    );

    expect(streak.current, 1);
    expect(streak.best, 2); // the older 2-day run still counts for "best"
  });

  test('best streak can exceed the current streak', () {
    final streak = Streak.compute(
      metric: StreakMetric.calories,
      // A 5-day run far in the past, then a gap, then just yesterday met.
      metDays: {
        daysBefore(1),
        daysBefore(10),
        daysBefore(11),
        daysBefore(12),
        daysBefore(13),
        daysBefore(14),
      },
      todayMet: false,
      today: today,
    );

    expect(streak.current, 1);
    expect(streak.best, 5);
  });

  test('today not yet met never breaks a streak still in progress', () {
    final streak = Streak.compute(
      metric: StreakMetric.water,
      metDays: {daysBefore(1), daysBefore(2)},
      todayMet: false,
      today: today,
    );

    expect(streak.current, 2);
  });

  test('handles a month boundary correctly', () {
    final marchFirst = DateTime(2026, 3, 1);
    final febTwentyEighth = DateTime(2026, 2, 28); // 2026 is not a leap year

    final streak = Streak.compute(
      metric: StreakMetric.steps,
      metDays: {febTwentyEighth},
      todayMet: true,
      today: marchFirst,
    );

    expect(streak.current, 2);
    expect(streak.best, 2);
  });

  test('handles a DST-transition day boundary correctly', () {
    // Central Europe: clocks spring forward on the last Sunday of March.
    final dstDay = DateTime(2026, 3, 29);
    final dayBeforeDst = DateTime(2026, 3, 28);

    final streak = Streak.compute(
      metric: StreakMetric.water,
      metDays: {dayBeforeDst},
      todayMet: true,
      today: dstDay,
    );

    expect(streak.current, 2);
    expect(streak.best, 2);
  });
}
