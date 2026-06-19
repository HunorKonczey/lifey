/// A reusable workout template: a named list of exercise clientIds
/// (`/workout-templates`).
class WorkoutTemplate {
  const WorkoutTemplate({
    required this.clientId,
    required this.name,
    required this.exerciseClientIds,
    this.id,
  });

  final String clientId;
  final int? id;
  final String name;
  final List<String> exerciseClientIds;
}
