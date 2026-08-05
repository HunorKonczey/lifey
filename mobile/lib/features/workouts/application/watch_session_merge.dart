import '../data/workout_session_repository.dart';
import '../domain/workout_session.dart';

/// The exercises + sets to write for a watch-mastered session, combining what
/// the watch just sent with what is already on the row.
class MergedWatchSessionContent {
  const MergedWatchSessionContent({required this.exercises, required this.sets});

  final List<PlannedExerciseInput> exercises;
  final List<ExerciseSetInput> sets;
}

/// A watch-started session is **not** only ever written by the watch: its
/// mirror screen on the phone stays fully editable, so sets get logged there
/// too. The watch, meanwhile, knows nothing about those — it resends its own
/// complete set list after every tap, and writing that list as-is (the
/// straight full replace this used to be) deleted every phone-logged set,
/// locally *and* on the server via the outbox. The same happened one last time
/// when the workout ended on the wrist, so even a phone set logged after the
/// final tap didn't survive.
///
/// So merge rather than replace:
///
/// - **Sets**: everything the watch sent, plus every existing set the watch's
///   batch doesn't account for (i.e. logged on the phone). Where both sides
///   describe the same set, the existing row wins — it may carry a correction
///   the user typed on the phone, and keeping it also stops the inferred
///   weight for a bare "+1" tap ([StandaloneSessionProcessor._resolveWeights])
///   from being recomputed differently on every resend.
/// - **Exercises**: the **stored** plan, keeping each exercise's stored
///   `targetSets` when it has one (that's the phone's live row count, which
///   "+ Add set" may have grown past the template's number) and falling back
///   to the watch's number otherwise, plus any exercise the merged set list
///   references that the plan no longer has — without its link the session's
///   own screen can't render that exercise's sets at all, so dropping it would
///   hide them even though the merge above kept them.
///
/// The stored plan winning is what makes an exercise **removed on the phone**
/// stay removed. The watch's list is derived from the *template* it started
/// from ([StandaloneSessionProcessor._resolveExercisesAndSets]) and knows
/// nothing about the mirror screen's edits, so re-deriving the plan from it on
/// every resend put a deleted exercise straight back — "random idő után
/// visszajön a törölt gyakorlat", where the random time was simply the next
/// tap on the wrist (or a reconnect). The row's own plan is seeded from that
/// same template when the mirror is first created, so nothing is lost by
/// treating it as the newer answer from then on: an add and a removal are both
/// edits it already carries.
///
/// An exercise whose sets survive the merge is the one exception — logged data
/// outranks a plan edit, and a link-less set is invisible on the phone. In
/// practice that only happens for an exercise the wrist has already logged
/// into, which the watch keeps resending by design (49-doc §3.5: a logged
/// set's `exerciseIndex` is permanent).
///
/// Sets are matched on **whole seconds + exercise**, not on the exact
/// timestamp: Drift stores a `DateTime` as unix *seconds*, so the millisecond
/// precision the watch sends is already gone from the stored copy and the two
/// sides would never compare equal. (Two sets of the same exercise inside one
/// second can't be told apart by this key — the phone's would be treated as
/// the watch's and dropped. That needs a per-set origin marker to fix
/// properly; it's a far narrower window than the guaranteed loss it replaces.)
MergedWatchSessionContent mergeWatchSessionContent({
  required List<SessionExercise> existingExercises,
  required List<ExerciseSet> existingSets,
  required List<PlannedExerciseInput> watchExercises,
  required List<ExerciseSetInput> watchSets,
}) {
  final existingByKey = {
    for (final set in existingSets) _setKey(set.exerciseClientId, set.performedAt): set,
  };

  final sets = <ExerciseSetInput>[];
  final claimed = <String>{};
  for (final watchSet in watchSets) {
    final key = _setKey(watchSet.exerciseClientId, watchSet.performedAt);
    claimed.add(key);
    final existing = existingByKey[key];
    sets.add(existing == null
        ? watchSet
        : ExerciseSetInput(
            exerciseClientId: existing.exerciseClientId,
            reps: existing.reps,
            weight: existing.weight,
            performedAt: existing.performedAt,
          ));
  }
  for (final entry in existingByKey.entries) {
    if (claimed.contains(entry.key)) continue;
    final set = entry.value;
    sets.add(ExerciseSetInput(
      exerciseClientId: set.exerciseClientId,
      reps: set.reps,
      weight: set.weight,
      performedAt: set.performedAt,
    ));
  }
  sets.sort((a, b) => a.performedAt.compareTo(b.performedAt));

  final watchTargetSets = <String, int>{
    for (final exercise in watchExercises)
      if (exercise.targetSets != null) exercise.exerciseClientId: exercise.targetSets!,
  };
  final exercises = [
    for (final exercise in existingExercises)
      PlannedExerciseInput(
        exerciseClientId: exercise.exerciseClientId,
        targetSets: exercise.targetSets ?? watchTargetSets[exercise.exerciseClientId],
      ),
  ];
  // Only a set that survived the merge above can re-add an exercise the stored
  // plan doesn't list — never the watch's plan on its own, which would undo a
  // removal made on the phone.
  final planned = {for (final exercise in exercises) exercise.exerciseClientId};
  for (final set in sets) {
    if (!planned.add(set.exerciseClientId)) continue;
    exercises.add(PlannedExerciseInput(
      exerciseClientId: set.exerciseClientId,
      targetSets: watchTargetSets[set.exerciseClientId],
    ));
  }

  return MergedWatchSessionContent(exercises: exercises, sets: sets);
}

/// See [mergeWatchSessionContent]'s note on precision. `millisecondsSinceEpoch`
/// is absolute, so this compares the same instant whether the `DateTime` came
/// back from Drift as local time or was built as UTC from the watch's payload —
/// which `DateTime.==` would not (it also compares the utc flag).
String _setKey(String exerciseClientId, DateTime performedAt) =>
    '${performedAt.millisecondsSinceEpoch ~/ 1000}|$exerciseClientId';
