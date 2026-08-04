import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/watch_mirror_signature.dart';

final _startedAt = DateTime.utc(2026, 8, 3, 17);

WorkoutSession _session({
  DateTime? finishedAt,
  int? rpe,
  int? benchTargetSets = 3,
  String benchName = 'Bench press',
  List<ExerciseSet> sets = const [],
  double? activeCalories,
  String? templateName,
  int? id,
}) {
  return WorkoutSession(
    clientId: 'sess-1',
    id: id,
    startedAt: _startedAt,
    finishedAt: finishedAt,
    rpe: rpe,
    activeCalories: activeCalories,
    templateName: templateName,
    exercises: [
      SessionExercise(
        exerciseClientId: 'ex-bench',
        exerciseName: benchName,
        targetSets: benchTargetSets,
      ),
    ],
    sets: sets,
  );
}

ExerciseSet _set({
  int reps = 8,
  double weight = 60,
  int minute = 0,
  String exerciseClientId = 'ex-bench',
}) {
  return ExerciseSet(
    exerciseClientId: exerciseClientId,
    exerciseName: 'Bench press',
    reps: reps,
    weight: weight,
    performedAt: _startedAt.add(Duration(minutes: minute)),
  );
}

void main() {
  test('two reads of an unchanged session produce the same signature', () {
    expect(
      watchMirrorSignature(_session(sets: [_set()])),
      watchMirrorSignature(_session(sets: [_set()])),
    );
  });

  group('changes the mirror must react to', () {
    test('a newly logged set', () {
      expect(
        watchMirrorSignature(_session(sets: [_set()])),
        isNot(watchMirrorSignature(_session(sets: [_set(), _set(minute: 3)]))),
      );
    });

    test('an edited set', () {
      expect(
        watchMirrorSignature(_session(sets: [_set(reps: 8)])),
        isNot(watchMirrorSignature(_session(sets: [_set(reps: 10)]))),
      );
      expect(
        watchMirrorSignature(_session(sets: [_set(weight: 60)])),
        isNot(watchMirrorSignature(_session(sets: [_set(weight: 62.5)]))),
      );
      expect(
        watchMirrorSignature(_session(sets: [_set(minute: 1)])),
        isNot(watchMirrorSignature(_session(sets: [_set(minute: 2)]))),
      );
    });

    test('the same set moved to another exercise', () {
      expect(
        watchMirrorSignature(_session(sets: [_set()])),
        isNot(watchMirrorSignature(
            _session(sets: [_set(exerciseClientId: 'ex-squat')]))),
      );
    });

    test('the planned set count (the blank rows the screen renders)', () {
      expect(
        watchMirrorSignature(_session(benchTargetSets: 3)),
        isNot(watchMirrorSignature(_session(benchTargetSets: null))),
      );
    });

    test('an exercise name arriving late', () {
      expect(
        watchMirrorSignature(_session(benchName: 'Unknown')),
        isNot(watchMirrorSignature(_session(benchName: 'Bench press'))),
      );
    });

    test('the workout finishing on the watch', () {
      expect(
        watchMirrorSignature(_session()),
        isNot(watchMirrorSignature(
            _session(finishedAt: _startedAt.add(const Duration(hours: 1))))),
      );
    });

    test('the effort rating the watch collected', () {
      expect(
        watchMirrorSignature(_session()),
        isNot(watchMirrorSignature(_session(rpe: 7))),
      );
    });
  });

  group('churn the mirror must ignore', () {
    test('health enrichment resent with every adoption snapshot', () {
      // _refreshRunningSession rewrites activeCalories/averageHeartRate on
      // every resend; none of it is anything _applyWatchMirror renders.
      expect(
        watchMirrorSignature(_session(sets: [_set()], activeCalories: 120)),
        watchMirrorSignature(_session(sets: [_set()], activeCalories: 148)),
      );
    });

    test('a serverId landing after the create syncs', () {
      expect(
        watchMirrorSignature(_session(sets: [_set()])),
        watchMirrorSignature(_session(sets: [_set()], id: 42)),
      );
    });

    test('a template rename pulled from the server', () {
      expect(
        watchMirrorSignature(_session(templateName: 'Push A')),
        watchMirrorSignature(_session(templateName: 'Push A (v2)')),
      );
    });
  });
}
