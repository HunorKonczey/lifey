/// Domain model for a day's step total (`/steps`).
class DailyStepCount {
  const DailyStepCount({
    required this.clientId,
    required this.date,
    required this.steps,
    this.id,
  });

  /// Local identifier, stable from the moment this row is created —
  /// online or offline. Use this (not [id]) for list keys and delete calls.
  final String clientId;

  /// The backend's id, null until this entry has synced.
  final int? id;
  final DateTime date;
  final int steps;
}
