/// Domain model for a body weight entry (`/weights`).
class WeightEntry {
  const WeightEntry({
    required this.clientId,
    required this.date,
    required this.weight,
    this.id,
  });

  /// Local identifier, stable from the moment this entry is created —
  /// online or offline. Use this (not [id]) for list keys and delete calls.
  final String clientId;

  /// The backend's id, null until this entry has synced.
  final int? id;
  final DateTime date;
  final double weight;
}
