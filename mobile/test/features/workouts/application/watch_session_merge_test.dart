import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/application/watch_session_merge.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// A set as it comes back from Drift: local time, truncated to whole seconds.
ExerciseSet stored({
  String exerciseClientId = 'ex-bench',
  int reps = 8,
  double weight = 60,
  required int epochMs,
}) {
  return ExerciseSet(
    exerciseClientId: exerciseClientId,
    exerciseName: 'Bench press',
    reps: reps,
    weight: weight,
    performedAt: DateTime.fromMillisecondsSinceEpoch(epochMs - epochMs % 1000),
  );
}

/// A set as the watch sends it: UTC, millisecond precision.
ExerciseSetInput fromWatch({
  String exerciseClientId = 'ex-bench',
  int reps = 8,
  double weight = 60,
  required int epochMs,
}) {
  return ExerciseSetInput(
    exerciseClientId: exerciseClientId,
    reps: reps,
    weight: weight,
    performedAt: DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true),
  );
}

SessionExercise plannedExercise(String exerciseClientId, {int? targetSets}) => SessionExercise(
      exerciseClientId: exerciseClientId,
      exerciseName: exerciseClientId,
      targetSets: targetSets,
    );

void main() {
  group('sets', () {
    test('a phone-logged set survives the watch resending its own list', () {
      final merged = mergeWatchSessionContent(
        existingExercises: const [],
        existingSets: [
          stored(epochMs: 1000000),
          stored(epochMs: 1060000, reps: 10, weight: 70), // logged on the phone
        ],
        watchExercises: const [],
        watchSets: [fromWatch(epochMs: 1000123)],
      );

      expect(merged.sets, hasLength(2));
      expect(merged.sets.last.reps, 10);
      expect(merged.sets.last.weight, 70);
    });

    test('a new watch set is added without dropping the phone-logged one', () {
      final merged = mergeWatchSessionContent(
        existingExercises: const [],
        existingSets: [
          stored(epochMs: 1000000),
          stored(epochMs: 1060000, reps: 10),
        ],
        watchExercises: const [],
        watchSets: [
          fromWatch(epochMs: 1000123),
          fromWatch(epochMs: 1120456, reps: 6), // the tap that used to wipe the phone's
        ],
      );

      expect(
        merged.sets.map((s) => s.performedAt.millisecondsSinceEpoch ~/ 1000),
        [1000, 1060, 1120],
      );
    });

    test('millisecond precision the database threw away still matches', () {
      // Drift stores unix *seconds*, so the stored copy of a watch set never
      // equals the payload's DateTime — matching has to be second-granular, or
      // every resend would duplicate its whole list.
      final merged = mergeWatchSessionContent(
        existingExercises: const [],
        existingSets: [stored(epochMs: 1000000)],
        watchExercises: const [],
        watchSets: [fromWatch(epochMs: 1000999)],
      );

      expect(merged.sets, hasLength(1));
    });

    test('a correction typed on the phone is not overwritten by the resend', () {
      final merged = mergeWatchSessionContent(
        existingExercises: const [],
        existingSets: [stored(epochMs: 1000000, reps: 12, weight: 82.5)],
        watchExercises: const [],
        watchSets: [fromWatch(epochMs: 1000000, reps: 8, weight: 60)],
      );

      expect(merged.sets.single.reps, 12);
      expect(merged.sets.single.weight, 82.5);
    });

    test('the same second on a different exercise is a different set', () {
      final merged = mergeWatchSessionContent(
        existingExercises: const [],
        existingSets: [stored(exerciseClientId: 'ex-squat', epochMs: 1000000)],
        watchExercises: const [],
        watchSets: [fromWatch(exerciseClientId: 'ex-bench', epochMs: 1000000)],
      );

      expect(merged.sets, hasLength(2));
    });

    test('the merged list is ordered by time', () {
      final merged = mergeWatchSessionContent(
        existingExercises: const [],
        existingSets: [stored(epochMs: 1090000)],
        watchExercises: const [],
        watchSets: [fromWatch(epochMs: 1000000), fromWatch(epochMs: 1120000)],
      );

      expect(
        merged.sets.map((s) => s.performedAt.millisecondsSinceEpoch ~/ 1000),
        [1000, 1090, 1120],
      );
    });

    test('nothing stored yet leaves the watch list exactly as it is', () {
      final merged = mergeWatchSessionContent(
        existingExercises: const [],
        existingSets: const [],
        watchExercises: const [],
        watchSets: [fromWatch(epochMs: 1000000), fromWatch(epochMs: 1060000)],
      );

      expect(merged.sets, hasLength(2));
    });
  });

  group('exercises', () {
    test('the stored targetSets wins over the template plan', () {
      // "+ Add set" on the phone grew the plan; the watch only knows the
      // template's original number.
      final merged = mergeWatchSessionContent(
        existingExercises: [plannedExercise('ex-bench', targetSets: 5)],
        existingSets: const [],
        watchExercises: const [PlannedExerciseInput(exerciseClientId: 'ex-bench', targetSets: 3)],
        watchSets: const [],
      );

      expect(merged.exercises.single.targetSets, 5);
    });

    test('the template plan is used when nothing is stored for it', () {
      final merged = mergeWatchSessionContent(
        existingExercises: [plannedExercise('ex-bench')],
        existingSets: const [],
        watchExercises: const [PlannedExerciseInput(exerciseClientId: 'ex-bench', targetSets: 3)],
        watchSets: const [],
      );

      expect(merged.exercises.single.targetSets, 3);
    });

    test('an exercise added on the phone is kept', () {
      // Without its link the session screen iterates only the template's
      // exercises, so the sets merged above would be invisible.
      final merged = mergeWatchSessionContent(
        existingExercises: [
          plannedExercise('ex-bench', targetSets: 3),
          plannedExercise('ex-curl', targetSets: 2),
        ],
        existingSets: const [],
        watchExercises: const [PlannedExerciseInput(exerciseClientId: 'ex-bench', targetSets: 3)],
        watchSets: const [],
      );

      expect(
        merged.exercises.map((e) => e.exerciseClientId),
        ['ex-bench', 'ex-curl'],
      );
      expect(merged.exercises.last.targetSets, 2);
    });

    test('the stored plan order wins — that is the one the phone shows', () {
      final merged = mergeWatchSessionContent(
        existingExercises: [plannedExercise('ex-squat'), plannedExercise('ex-bench')],
        existingSets: const [],
        watchExercises: const [
          PlannedExerciseInput(exerciseClientId: 'ex-bench'),
          PlannedExerciseInput(exerciseClientId: 'ex-squat'),
        ],
        watchSets: const [],
      );

      expect(merged.exercises.map((e) => e.exerciseClientId), ['ex-squat', 'ex-bench']);
    });

    test('an exercise removed on the phone stays removed', () {
      // The watch keeps resending the template's full plan after every tap;
      // re-deriving from it put the deleted exercise back "random idő után".
      final merged = mergeWatchSessionContent(
        existingExercises: [plannedExercise('ex-bench', targetSets: 3)],
        existingSets: const [],
        watchExercises: const [
          PlannedExerciseInput(exerciseClientId: 'ex-bench', targetSets: 3),
          PlannedExerciseInput(exerciseClientId: 'ex-squat', targetSets: 4),
        ],
        watchSets: const [],
      );

      expect(merged.exercises.map((e) => e.exerciseClientId), ['ex-bench']);
    });

    test('…unless the wrist already logged a set into it — the set needs its link', () {
      final merged = mergeWatchSessionContent(
        existingExercises: [plannedExercise('ex-bench', targetSets: 3)],
        existingSets: const [],
        watchExercises: const [
          PlannedExerciseInput(exerciseClientId: 'ex-bench', targetSets: 3),
          PlannedExerciseInput(exerciseClientId: 'ex-squat', targetSets: 4),
        ],
        watchSets: [fromWatch(exerciseClientId: 'ex-squat', epochMs: 1000)],
      );

      expect(merged.exercises.map((e) => e.exerciseClientId), ['ex-bench', 'ex-squat']);
      expect(merged.exercises.last.targetSets, 4);
      expect(merged.sets.single.exerciseClientId, 'ex-squat');
    });

    test('a phone-only exercise with no sets at all is kept', () {
      // The mirror screen can add an exercise before anything is logged into
      // it; the resend must not treat "the watch never heard of it" as
      // "delete it".
      final merged = mergeWatchSessionContent(
        existingExercises: [plannedExercise('ex-bench'), plannedExercise('ex-curl', targetSets: 2)],
        existingSets: const [],
        watchExercises: const [PlannedExerciseInput(exerciseClientId: 'ex-bench')],
        watchSets: const [],
      );

      expect(merged.exercises.map((e) => e.exerciseClientId), ['ex-bench', 'ex-curl']);
      expect(merged.exercises.last.targetSets, 2);
    });
  });
}
