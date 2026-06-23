/// Domain model for a body weight entry (`/weights`).
class WeightEntry {
  const WeightEntry({
    required this.clientId,
    required this.date,
    required this.weight,
    required this.recordedAt,
    this.id,
  });

  /// Local identifier, stable from the moment this entry is created —
  /// online or offline. Use this (not [id]) for list keys and delete calls.
  final String clientId;

  /// The backend's id, null until this entry has synced.
  final int? id;
  final DateTime date;
  final double weight;

  /// Local-only timestamp of when this entry was first recorded on this
  /// device (not synced — `date` is the day the weight applies to, this is
  /// when it was logged). Used by the Apple Health importer to dedup against
  /// a measurement the user just logged manually.
  final DateTime recordedAt;
}
