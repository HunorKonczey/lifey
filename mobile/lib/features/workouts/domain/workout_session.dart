/// A single set within a logged session (response side).
class ExerciseSet {
  const ExerciseSet({
    required this.exerciseId,
    required this.exerciseName,
    required this.reps,
    required this.weight,
  });

  final int exerciseId;
  final String exerciseName;
  final int reps;
  final double weight;

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      exerciseId: json['exerciseId'] as int,
      exerciseName: json['exerciseName'] as String? ?? 'Unknown',
      reps: (json['reps'] as num).toInt(),
      weight: (json['weight'] as num).toDouble(),
    );
  }
}

/// An exercise planned for a session (a quick-add default) — e.g. copied in
/// from a template at creation time — independent of how many [ExerciseSet]s
/// have actually been logged for it.
class SessionExercise {
  const SessionExercise({required this.exerciseId, required this.exerciseName});

  final int exerciseId;
  final String exerciseName;

  factory SessionExercise.fromJson(Map<String, dynamic> json) {
    return SessionExercise(
      exerciseId: json['exerciseId'] as int,
      exerciseName: json['exerciseName'] as String? ?? 'Unknown',
    );
  }
}

/// A logged workout session (`/workout-sessions`).
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.startedAt,
    required this.exercises,
    required this.sets,
    this.finishedAt,
  });

  final int id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<SessionExercise> exercises;
  final List<ExerciseSet> sets;

  bool get inProgress => finishedAt == null;

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final finished = json['finishedAt'] as String?;
    final exercises = (json['exercises'] as List<dynamic>? ?? const [])
        .map((e) => SessionExercise.fromJson(e as Map<String, dynamic>))
        .toList();
    final sets = (json['sets'] as List<dynamic>? ?? const [])
        .map((e) => ExerciseSet.fromJson(e as Map<String, dynamic>))
        .toList();
    return WorkoutSession(
      id: json['id'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      finishedAt: finished != null ? DateTime.parse(finished) : null,
      exercises: exercises,
      sets: sets,
    );
  }
}
