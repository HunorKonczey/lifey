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
    this.originTrainerId,
  });

  final String clientId;
  final int? id;
  final String name;
  final List<TemplateExercise> exercises;

  /// Non-null only for a trainer-assigned copy (docs/personal_trainer/05-mobil-terv.md
  /// §2) — the trainer's server-side user id, drives the "Edzőtől" badge.
  final int? originTrainerId;

  /// Convenience accessor used by screens that only need the exercise ids
  /// (LogSessionScreen, CreateTemplateScreen, TemplatesTab subtitle).
  List<String> get exerciseClientIds =>
      exercises.map((e) => e.exerciseClientId).toList();
}
