/// Domain model for a body weight entry (`/weights`).
class WeightEntry {
  const WeightEntry({
    required this.clientId,
    required this.date,
    required this.weight,
    required this.recordedAt,
    this.id,
    this.note,
  });

  /// Local identifier, stable from the moment this entry is created —
  /// online or offline. Use this (not [id]) for list keys and delete calls.
  final String clientId;

  /// The backend's id, null until this entry has synced.
  final int? id;
  final DateTime date;
  final double weight;

  /// When this entry was taken (`date` is the day the weight applies to, this
  /// is when it was logged). Synced since LIF-115: the device sends its own
  /// time, so an entry logged offline keeps it, and an entry from another
  /// device arrives with the time it was taken there. Also used by the Apple
  /// Health importer to dedup against a measurement the user just logged.
  final DateTime recordedAt;

  /// Optional free text about the weigh-in, at most 280 characters.
  final String? note;

  /// The time of day to show next to [date], or null when it would mislead:
  /// an entry logged for another day than the one it was taken on (a
  /// back-dated weigh-in) has no meaningful time.
  DateTime? get takenAt {
    final taken = recordedAt.toLocal();
    final day = date.toLocal();
    final sameDay = taken.year == day.year && taken.month == day.month && taken.day == day.day;
    return sameDay ? taken : null;
  }
}
