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
    // Calendar arithmetic, not `subtract(Duration(days:))`: a Duration is
    // exactly 24 h × n, so a range spanning a DST change landed an hour off
    // local midnight — 01:00 after the clocks go back (which then *excludes*
    // the boundary day, since its own midnight `isBefore` the cutoff), 23:00
    // the previous day after they go forward (which includes one day too
    // many). `DateTime`'s constructor normalizes an out-of-range day, so
    // `day - daysBack` rolls back across month/year ends on its own.
    return DateTime(today.year, today.month, today.day - daysBack);
  }
}
