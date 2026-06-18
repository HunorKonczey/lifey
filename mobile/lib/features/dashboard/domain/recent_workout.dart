/// A summarised workout session for the dashboard's "Recent workouts" list,
/// derived from `GET /workout-sessions`.
class RecentWorkout {
  const RecentWorkout({
    required this.id,
    required this.startedAt,
    required this.setCount,
    required this.exerciseNames,
    this.finishedAt,
  });

  final int id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int setCount;
  final List<String> exerciseNames;

  bool get inProgress => finishedAt == null;

  factory RecentWorkout.fromJson(Map<String, dynamic> json) {
    final sets = (json['sets'] as List<dynamic>? ?? const []);
    final names = <String>{};
    for (final set in sets) {
      final name = (set as Map<String, dynamic>)['exerciseName'] as String?;
      if (name != null) names.add(name);
    }
    final finished = json['finishedAt'] as String?;
    return RecentWorkout(
      id: json['id'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      finishedAt: finished != null ? DateTime.parse(finished) : null,
      setCount: sets.length,
      exerciseNames: names.toList(),
    );
  }
}
