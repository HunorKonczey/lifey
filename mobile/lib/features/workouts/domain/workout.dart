/// Domain model for a workout template.
class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.name,
    this.exerciseIds = const [],
  });

  final int id;
  final String name;
  final List<int> exerciseIds;
}

/// Domain model for a logged workout session.
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    this.sets = const [],
  });

  final int id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<ExerciseSet> sets;
}

/// A single set within a workout session.
class ExerciseSet {
  const ExerciseSet({
    required this.exerciseId,
    required this.reps,
    required this.weight,
  });

  final int exerciseId;
  final int reps;
  final double weight;
}
