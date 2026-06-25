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
  const SessionExercise({
    required this.exerciseClientId,
    required this.exerciseName,
    this.targetSets,
  });

  final String exerciseClientId;
  final String exerciseName;
  final int? targetSets;
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
    this.activeCalories,
    this.averageHeartRate,
    this.healthWorkoutId,
  });

  final String clientId;
  final int? id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<SessionExercise> exercises;
  final List<ExerciseSet> sets;

  /// Active energy burned (kcal), imported from Apple Health.
  final double? activeCalories;

  /// Average heart rate (bpm) over the workout, imported from Apple Health.
  final double? averageHeartRate;

  /// HKWorkout UUID this session was paired with, if imported from Apple Health.
  final String? healthWorkoutId;

  bool get inProgress => finishedAt == null;

  bool get fromAppleHealth => healthWorkoutId != null;
}
