/// The three daily goals a streak can be tracked against
/// (docs/37-streaks-weekly-recap-plan.md).
enum StreakMetric { calories, steps, water }

/// A metric's current/best consecutive-day streak, purely derived — never
/// persisted (see [Streak.compute]).
class Streak {
  const Streak({
    required this.metric,
    required this.current,
    required this.best,
    required this.todayMet,
  });

  final StreakMetric metric;

  /// Consecutive met days ending at yesterday, plus one more if [todayMet] —
  /// today not yet being met never breaks the streak (the day isn't over).
  final int current;

  /// The longest consecutive run anywhere in the history considered.
  final int best;

  /// Whether today's goal has already been reached.
  final bool todayMet;

  /// Whether the current streak is alive at all — a plain `current > 0`
  /// accessor kept as a named getter since callers reach for this constantly
  /// (deciding chip styling).
  bool get isActive => current > 0;

  /// Computes a metric's streak from the set of *past* days (before [today])
  /// that met the goal, plus whether [today] itself has already met it.
  ///
  /// [metDays] must contain local-midnight [DateTime]s strictly before
  /// [today] — the caller is responsible for excluding today itself (its
  /// state is carried separately via [todayMet], since "not yet met" and
  /// "the day ended without meeting it" are different things for a day
  /// that isn't over).
  ///
  /// Pure and clock-free beyond the passed-in [today]: no DB or repository
  /// access, so this is trivially unit-testable with synthetic dates.
  factory Streak.compute({
    required StreakMetric metric,
    required Set<DateTime> metDays,
    required bool todayMet,
    required DateTime today,
  }) {
    var current = 0;
    var cursor = _previousDay(today);
    while (metDays.contains(cursor)) {
      current++;
      cursor = _previousDay(cursor);
    }
    if (todayMet) current++;

    final timeline = <DateTime>{...metDays, if (todayMet) today};
    final best = _longestRun(timeline);

    return Streak(metric: metric, current: current, best: best, todayMet: todayMet);
  }
}

/// Field-based subtraction (not `Duration(days: 1)`) so a day boundary that
/// crosses a DST transition still lands on an exact local midnight — a
/// `Duration`-based subtraction can land an hour off across the transition,
/// which would silently break the `Set<DateTime>.contains` lookups above.
DateTime _previousDay(DateTime day) => DateTime(day.year, day.month, day.day - 1);

int _longestRun(Set<DateTime> days) {
  if (days.isEmpty) return 0;

  final sorted = days.toList()..sort();
  var best = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    final isConsecutive = sorted[i] == _nextDay(sorted[i - 1]);
    run = isConsecutive ? run + 1 : 1;
    if (run > best) best = run;
  }
  return best;
}

DateTime _nextDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);
