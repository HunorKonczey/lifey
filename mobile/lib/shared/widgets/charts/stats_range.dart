/// How much history a time-series chart shows. [all] has no cutoff.
///
/// Feature-agnostic: extracted from the weight feature's range selector so
/// other daily-metric charts (statistics tab) can reuse the same cutoff
/// logic instead of redefining their own day counts.
enum StatsRange {
  week,
  month,
  quarter,
  all;

  /// The oldest local-midnight date still included, or null for [all].
  DateTime? cutoff() {
    if (this == StatsRange.all) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysBack = switch (this) {
      StatsRange.week => 6,
      StatsRange.month => 29,
      StatsRange.quarter => 89,
      StatsRange.all => 0,
    };
    return today.subtract(Duration(days: daysBack));
  }
}
