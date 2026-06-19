/// A summarised workout session for the dashboard's "Recent workouts" list,
/// derived from the local workout-sessions cache.
class RecentWorkout {
  const RecentWorkout({
    required this.clientId,
    required this.startedAt,
    required this.setCount,
    required this.exerciseNames,
    this.finishedAt,
  });

  final String clientId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int setCount;
  final List<String> exerciseNames;

  bool get inProgress => finishedAt == null;
}
