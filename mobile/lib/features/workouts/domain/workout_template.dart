/// A reusable workout template: a named list of exercise ids (`/workout-templates`).
class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.name,
    required this.exerciseIds,
  });

  final int id;
  final String name;
  final List<int> exerciseIds;

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    final ids = (json['exerciseIds'] as List<dynamic>? ?? const [])
        .map((e) => e as int)
        .toList();
    return WorkoutTemplate(
      id: json['id'] as int,
      name: json['name'] as String,
      exerciseIds: ids,
    );
  }
}
