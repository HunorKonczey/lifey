import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/week_summary.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

// Thursday 24 Sep 2026: the week is Mon 21 – Sun 27 Sep.
final _now = DateTime(2026, 9, 24, 10);

WorkoutSession _strength(DateTime start, {int minutes = 30, bool finished = true}) => WorkoutSession(
      clientId: 's${start.millisecondsSinceEpoch}',
      exercises: const [],
      sets: const [],
      startedAt: start,
      finishedAt: finished ? start.add(Duration(minutes: minutes)) : null,
    );

WorkoutSession _cardio(DateTime start, String type, {double? meters, int movingSeconds = 1800, bool finished = true}) =>
    WorkoutSession(
      clientId: 'c${start.millisecondsSinceEpoch}',
      exercises: const [],
      sets: const [],
      startedAt: start,
      finishedAt: finished ? start.add(Duration(seconds: movingSeconds)) : null,
      sessionKind: 'CARDIO',
      activityType: type,
      movingSeconds: movingSeconds,
      cardio: CardioMetrics(distanceMeters: meters),
    );

void main() {
  test('the canvas week: 3 workouts, 96 minutes, 5.2 km', () {
    final summary = computeWeekSummary([
      _strength(DateTime(2026, 9, 24, 8), minutes: 58),
      _strength(DateTime(2026, 9, 23, 17, 30), minutes: 34),
      _cardio(DateTime(2026, 9, 22, 7, 45), 'RUNNING', meters: 5210, movingSeconds: 240),
    ], _now);

    expect(summary.workouts, 3);
    expect(summary.minutes, 58 + 34 + 4);
    expect(summary.distanceMeters, 5210);
  });

  test('the week starts on Monday: Sunday belongs to the previous week', () {
    final summary = computeWeekSummary([
      _strength(DateTime(2026, 9, 20, 18)), // Sun 20 Sep — last week
      _strength(DateTime(2026, 9, 21, 0, 5)), // Mon 21 Sep — this week
    ], _now);

    expect(summary.workouts, 1);
  });

  test('a running session counts as a workout but adds no minutes yet', () {
    final summary = computeWeekSummary([_strength(DateTime(2026, 9, 24, 9), finished: false)], _now);

    expect(summary.workouts, 1);
    expect(summary.minutes, 0);
  });

  test('a trainer-scheduled session that has not started is not counted', () {
    final upcoming = WorkoutSession(
      clientId: 'u',
      exercises: const [],
      sets: const [],
      scheduledFor: DateTime(2026, 9, 25),
    );

    expect(computeWeekSummary([upcoming], _now).workouts, 0);
  });

  test('distance is DISTANCE and MACHINE cardio only', () {
    final summary = computeWeekSummary([
      _cardio(DateTime(2026, 9, 21, 7), 'RUNNING', meters: 5000),
      _cardio(DateTime(2026, 9, 22, 7), 'INDOOR_BIKE', meters: 10000),
      _strength(DateTime(2026, 9, 23, 7)),
    ], _now);

    expect(summary.distanceMeters, 15000);
  });

  test('an empty week is empty', () {
    final summary = computeWeekSummary(const [], _now);

    expect(summary.isEmpty, isTrue);
    expect(summary.minutes, 0);
    expect(summary.distanceMeters, 0);
  });
}
