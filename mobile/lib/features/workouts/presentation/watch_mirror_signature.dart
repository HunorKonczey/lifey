import '../domain/workout_session.dart';

/// Everything [LogSessionScreen._applyWatchMirror] reads out of a mirrored
/// session, flattened into one comparable string.
///
/// The mirror listens to `workoutSessionControllerProvider`, whose stream is
/// re-emitted by *any* write to `workout_sessions` **or**
/// `pending_operations` (see [WorkoutSessionRepository.watchAll]) — including
/// outbox traffic from completely unrelated entities (water, steps, meals).
/// Rebuilding the screen on every one of those was both wasteful (a full
/// block rebuild plus a previous-performance and PR-baseline query per
/// exercise) and user-visible: each rebuild also re-pushed the workout state
/// to the watch. Comparing this signature first means the mirror reacts to
/// the watch's sets actually changing, not to the database being touched.
///
/// A plain string rather than value-equality on the domain classes: those are
/// plain immutable models shared by several screens, and only this one needs
/// "did the content change" semantics.
String watchMirrorSignature(WorkoutSession session) {
  final buffer = StringBuffer()
    ..write(session.startedAt?.microsecondsSinceEpoch)
    ..write('|')
    ..write(session.finishedAt?.microsecondsSinceEpoch)
    ..write('|')
    ..write(session.rpe)
    ..write('|');
  for (final exercise in session.exercises) {
    buffer
      ..write(exercise.exerciseClientId)
      ..write(':')
      // Included because the card renders it, and it can arrive late — a
      // session pulled before its exercises are shows "Unknown" until the
      // catalog lands.
      ..write(exercise.exerciseName)
      ..write(':')
      ..write(exercise.targetSets)
      ..write(',');
  }
  buffer.write('|');
  for (final set in session.sets) {
    buffer
      ..write(set.exerciseClientId)
      ..write(':')
      ..write(set.reps)
      ..write(':')
      ..write(set.weight)
      ..write(':')
      ..write(set.performedAt.microsecondsSinceEpoch)
      ..write(',');
  }
  return buffer.toString();
}
