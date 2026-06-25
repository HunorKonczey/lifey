/// One exercise entry inside a template, with an optional target set count.
class TemplateExercise {
  const TemplateExercise({required this.exerciseClientId, this.targetSets});

  final String exerciseClientId;
  final int? targetSets;
}

/// A reusable workout template: a named, ordered list of exercises with
/// optional per-exercise target set counts (`/workout-templates`).
class WorkoutTemplate {
  const WorkoutTemplate({
    required this.clientId,
    required this.name,
    required this.exercises,
    this.id,
  });

  final String clientId;
  final int? id;
  final String name;
  final List<TemplateExercise> exercises;

  /// Convenience accessor used by screens that only need the exercise ids
  /// (LogSessionScreen, CreateTemplateScreen, TemplatesTab subtitle).
  List<String> get exerciseClientIds =>
      exercises.map((e) => e.exerciseClientId).toList();
}
