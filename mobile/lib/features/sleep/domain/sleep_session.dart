/// A sleep session imported from the health store (`/sleep-sessions`,
/// docs/integrations/89 D-G7). Naps are sessions too; which one is the main
/// sleep of a night is decided by [mainSleepFor], not stored.
///
/// The measured values are read-only (D-G6): there is no update, only
/// create (by the importer) and delete.
class SleepSession {
  const SleepSession({
    required this.clientId,
    required this.startedAt,
    required this.endedAt,
    this.id,
    this.asleepMinutes,
    this.deepMinutes,
    this.lightMinutes,
    this.remMinutes,
    this.awakeMinutes,
    this.sourceAppName,
    this.healthRecordId,
  });

  final String clientId;

  /// Server id; null until the create syncs.
  final int? id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int? asleepMinutes;
  final int? deepMinutes;
  final int? lightMinutes;
  final int? remMinutes;
  final int? awakeMinutes;
  final String? sourceAppName;
  final String? healthRecordId;

  /// Time in bed, start to end.
  Duration get duration => endedAt.difference(startedAt);

  /// True when the source recorded at least one sleep stage.
  bool get hasStages =>
      deepMinutes != null || lightMinutes != null || remMinutes != null || awakeMinutes != null;

  /// The local calendar date the session ended on: the night it counts for.
  /// A sleep from 23:30 to 07:00 belongs to the morning it ended (D-G7).
  DateTime get wakeDate {
    final local = endedAt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

/// The main sleep of the night that ended on [date] (a local calendar date):
/// the longest session whose [SleepSession.wakeDate] is [date]. Naps on the
/// same day lose to it. Null when nothing ended that day.
SleepSession? mainSleepFor(Iterable<SleepSession> sessions, DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  SleepSession? best;
  for (final s in sessions) {
    if (s.wakeDate != day) continue;
    if (best == null || s.duration > best.duration) best = s;
  }
  return best;
}
