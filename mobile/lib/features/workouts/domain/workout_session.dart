/// A single set within a logged session (response side).
class ExerciseSet {
  const ExerciseSet({
    required this.exerciseClientId,
    required this.exerciseName,
    required this.reps,
    required this.weight,
    required this.performedAt,
  });

  final String exerciseClientId;
  final String exerciseName;
  final int reps;
  final double weight;
  final DateTime performedAt;
}

/// An exercise planned for a session (a quick-add default) — e.g. copied in
/// from a template at creation time — independent of how many [ExerciseSet]s
/// have actually been logged for it.
class SessionExercise {
  const SessionExercise({required this.exerciseClientId, required this.exerciseName});

  final String exerciseClientId;
  final String exerciseName;
}

/// A logged workout session (`/workout-sessions`).
class WorkoutSession {
  const WorkoutSession({
    required this.clientId,
    required this.startedAt,
    required this.exercises,
    required this.sets,
    this.id,
    this.finishedAt,
  });

  final String clientId;
  final int? id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<SessionExercise> exercises;
  final List<ExerciseSet> sets;

  bool get inProgress => finishedAt == null;
}
