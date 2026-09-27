import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/application/session_pr_counts.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

final _day1 = DateTime(2026, 9, 14, 18);
final _day2 = DateTime(2026, 9, 21, 18);
final _day3 = DateTime(2026, 9, 24, 8);

ExerciseSet _set(String exercise, double kg, int reps, DateTime at, {int minute = 0}) => ExerciseSet(
      exerciseClientId: exercise,
      exerciseName: exercise,
      reps: reps,
      weight: kg,
      performedAt: at.add(Duration(minutes: minute)),
    );

WorkoutSession _strength(String id, DateTime start, List<ExerciseSet> sets, {bool finished = true}) => WorkoutSession(
      clientId: id,
      exercises: const [],
      sets: sets,
      startedAt: start,
      finishedAt: finished ? start.add(const Duration(minutes: 50)) : null,
    );

WorkoutSession _run(String id, DateTime start, {required double meters, required int seconds}) => WorkoutSession(
      clientId: id,
      exercises: const [],
      sets: const [],
      startedAt: start,
      finishedAt: start.add(Duration(seconds: seconds)),
      sessionKind: 'CARDIO',
      activityType: 'RUNNING',
      movingSeconds: seconds,
      cardio: CardioMetrics(distanceMeters: meters),
    );

void main() {
  test('the first session of an exercise sets a baseline, it breaks no record', () {
    final counts = computeSessionPrCounts([_strength('a', _day1, [_set('bench', 47.5, 8, _day1)])]);

    expect(counts, isEmpty);
  });

  test('a heavier set with a better estimated 1RM is two records, as in the canvas', () {
    final counts = computeSessionPrCounts([
      _strength('a', _day1, [_set('bench', 47.5, 8, _day1)]),
      _strength('b', _day3, [_set('bench', 50, 8, _day3)]),
    ]);

    expect(counts, {'b': 2}); // heaviest set + estimated 1RM
  });

  test('records are counted once per exercise and type, however many sets beat the last', () {
    final counts = computeSessionPrCounts([
      _strength('a', _day1, [_set('bench', 40, 8, _day1)]),
      _strength('b', _day2, [
        _set('bench', 42.5, 8, _day2),
        _set('bench', 45, 8, _day2, minute: 4),
        _set('bench', 47.5, 8, _day2, minute: 8),
      ]),
    ]);

    expect(counts['b'], 2);
  });

  test('every exercise counts on its own', () {
    final counts = computeSessionPrCounts([
      _strength('a', _day1, [_set('bench', 40, 8, _day1), _set('ohp', 30, 8, _day1, minute: 10)]),
      _strength('b', _day2, [_set('bench', 42.5, 8, _day2), _set('ohp', 32.5, 8, _day2, minute: 10)]),
    ]);

    expect(counts['b'], 4);
  });

  test('a record has to beat the earlier sets of the same session too', () {
    final counts = computeSessionPrCounts([
      _strength('a', _day1, [_set('bench', 40, 8, _day1)]),
      _strength('b', _day2, [_set('bench', 50, 8, _day2), _set('bench', 45, 8, _day2, minute: 5)]),
    ]);

    expect(counts['b'], 2); // the 45 kg set is not a record after the 50 kg one
  });

  test('a session that only equals its best has no record', () {
    final counts = computeSessionPrCounts([
      _strength('a', _day1, [_set('bench', 50, 8, _day1)]),
      _strength('b', _day2, [_set('bench', 50, 8, _day2)]),
    ]);

    expect(counts, isEmpty);
  });

  test('editing an older session re-judges the later ones', () {
    final original = [
      _strength('a', _day1, [_set('bench', 40, 8, _day1)]),
      _strength('b', _day2, [_set('bench', 50, 8, _day2)]),
    ];
    expect(computeSessionPrCounts(original)['b'], 2);

    final edited = [
      _strength('a', _day1, [_set('bench', 55, 8, _day1)]), // the old session was heavier after all
      _strength('b', _day2, [_set('bench', 50, 8, _day2)]),
    ];
    expect(computeSessionPrCounts(edited).containsKey('b'), isFalse);
  });

  test('input order does not matter', () {
    final a = _strength('a', _day1, [_set('bench', 40, 8, _day1)]);
    final b = _strength('b', _day2, [_set('bench', 50, 8, _day2)]);

    expect(computeSessionPrCounts([b, a]), computeSessionPrCounts([a, b]));
  });

  test('an unfinished session has no records yet', () {
    final counts = computeSessionPrCounts([
      _strength('a', _day1, [_set('bench', 40, 8, _day1)]),
      _strength('b', _day2, [_set('bench', 50, 8, _day2)], finished: false),
    ]);

    expect(counts, isEmpty);
  });

  test('cardio: a longer and a longer-lasting run than any before', () {
    final counts = computeSessionPrCounts([
      _run('r1', _day1, meters: 5000, seconds: 1500),
      _run('r2', _day3, meters: 5210, seconds: 1660),
    ]);

    expect(counts, {'r2': 2}); // longest distance + longest moving time
  });

  test('cardio and strength records do not mix', () {
    final counts = computeSessionPrCounts([
      _strength('a', _day1, [_set('bench', 40, 8, _day1)]),
      _run('r1', _day1.add(const Duration(days: 1)), meters: 5000, seconds: 1500),
      _run('r2', _day2, meters: 4000, seconds: 1200),
    ]);

    expect(counts, isEmpty);
  });
}
