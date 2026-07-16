import '../../nutrition/domain/daily_macros.dart';
import '../../settings/domain/user_settings.dart';
import '../../steps/domain/daily_step_count.dart';
import '../../weight/domain/weight_entry.dart';
import '../../workouts/domain/workout_session.dart';
import 'streak.dart';

/// "Your week in review" — workouts, nutrition, weight trend and goal
/// consistency for one Monday–Sunday local week, purely derived from
/// full-history sources (see [WeeklyRecap.compute]). Never persisted, same
/// rationale as [Streak].
class WeeklyRecap {
  const WeeklyRecap({
    required this.weekStart,
    required this.workoutsDone,
    required this.workoutMinutes,
    required this.avgCalories,
    required this.loggedDayCount,
    required this.calorieGoalSet,
    required this.caloriesDaysMet,
    required this.stepGoalSet,
    required this.stepsDaysMet,
    required this.waterGoalSet,
    required this.waterDaysMet,
    required this.weightStart,
    required this.weightEnd,
    required this.streaks,
    required this.dailyCalories,
    required this.workoutDays,
  });

  /// Local-midnight Monday this recap covers (through the following Sunday,
  /// inclusive — see [weekEndInclusive]).
  final DateTime weekStart;

  /// Every non-upcoming session started this week, finished or not —
  /// matches `StatMetric.workoutCount`'s counting rule.
  final int workoutsDone;

  /// Sum of finished sessions' durations this week; an in-progress session
  /// contributes nothing (there's no duration yet) — matches
  /// `StatMetric.workoutMinutes`'s rule.
  final int workoutMinutes;

  /// Mean calories over days that actually had a meal logged this week —
  /// *not* divided by 7. An unlogged day is missing data, not a 0-kcal day,
  /// so it must not drag the average down. Null when nothing was logged.
  final double? avgCalories;

  /// How many of the week's 7 days had at least one meal logged — the
  /// denominator behind [avgCalories], shown so the UI can say e.g. "avg of
  /// 5 logged days" instead of implying a full week of data.
  final int loggedDayCount;

  final bool calorieGoalSet;

  /// Out of 7 — how many days this week met the calorie goal (logged *and*
  /// under budget, same rule [Streak] uses). Meaningless when
  /// [calorieGoalSet] is false.
  final int caloriesDaysMet;

  final bool stepGoalSet;

  /// Out of 7 — days this week that reached the step goal.
  final int stepsDaysMet;

  final bool waterGoalSet;

  /// Out of 7 — days this week that reached the water goal.
  final int waterDaysMet;

  /// Latest weight entry on or before [weekStart] — the baseline the week
  /// started from. Null with no such entry (e.g. a brand-new user).
  final double? weightStart;

  /// Latest weight entry logged *within* this week (not "as of week end" —
  /// a week with no weigh-in has no [weightEnd], rather than silently
  /// reusing an older value and implying a measurement that didn't happen).
  final double? weightEnd;

  /// Snapshot of the *current* live streaks (from `streaksProvider`), not
  /// "the streak as of this week" — there is only one current streak state,
  /// and showing it alongside a past week's recap is still useful context.
  /// Recomputing a historical point-in-time streak is deliberately out of
  /// scope (see docs/37-streaks-weekly-recap-plan.md).
  final List<Streak> streaks;

  /// One entry per weekday (Monday first, index 0..6) — the day's total
  /// calories, or null when nothing was logged that day. Backs the recap
  /// screen's mini bar chart.
  final List<double?> dailyCalories;

  /// One entry per weekday (Monday first) — true if a non-upcoming session
  /// started that day. Backs the recap screen's per-day workout dot strip.
  final List<bool> workoutDays;

  DateTime get weekEndInclusive => _addDays(weekStart, 6);

  /// Whether anything at all actually happened *in* this week — used by the
  /// dashboard's recap-ready card to stay hidden for a brand-new user's
  /// empty week rather than nudging toward an empty recap. Deliberately
  /// checks [weightEnd] (an in-week entry), not [weightStart] (which can be
  /// an old baseline that predates this week entirely).
  bool get hasAnyData => workoutsDone > 0 || loggedDayCount > 0 || weightEnd != null;

  /// Positive = gained, negative = lost. Null unless both ends of the week
  /// have a weight entry to compare.
  double? get weightDelta =>
      (weightStart == null || weightEnd == null) ? null : weightEnd! - weightStart!;

  /// The Monday (local midnight) of the week containing [day].
  static DateTime weekStartFor(DateTime day) {
    final local = day.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    return _addDays(today, -(today.weekday - 1));
  }

  /// The most recently *completed* week's Monday — the current week isn't
  /// over yet, so the default recap always looks one week back from
  /// whichever week [now] falls in.
  static DateTime lastCompletedWeekStart([DateTime? now]) {
    return _addDays(weekStartFor(now ?? DateTime.now()), -7);
  }

  factory WeeklyRecap.compute({
    required DateTime weekStart,
    required List<DailyMacros> dailyMacros,
    required List<WorkoutSession> sessions,
    required List<WeightEntry> weights,
    required Map<DateTime, double> dailyWaterLiters,
    required List<DailyStepCount> dailySteps,
    required UserSettings settings,
    required List<Streak> streaks,
  }) {
    final weekEnd = _addDays(weekStart, 6);
    bool inWeek(DateTime day) => !day.isBefore(weekStart) && !day.isAfter(weekEnd);

    final weekDays = [for (var i = 0; i < 7; i++) _addDays(weekStart, i)];
    // Field-based index lookup (not a `Duration` diff) — same DST-safety
    // reasoning as `streak.dart`'s day stepping: a `Duration` computed across
    // a DST transition can be an hour short of a full day and floor-divide
    // to the wrong index.
    int dayIndex(DateTime day) => weekDays.indexOf(day);

    var workoutsDone = 0;
    var workoutMinutes = 0;
    final workoutDays = List<bool>.filled(7, false);
    for (final session in sessions) {
      if (session.isUpcoming || session.startedAt == null) continue;
      final day = _localDay(session.startedAt!);
      if (!inWeek(day)) continue;
      workoutsDone++;
      workoutDays[dayIndex(day)] = true;
      final finishedAt = session.finishedAt;
      if (finishedAt != null) {
        workoutMinutes += finishedAt.difference(session.startedAt!).inMinutes;
      }
    }

    final weekMacros = dailyMacros.where((d) => inWeek(d.day)).toList();
    final dailyCalories = List<double?>.filled(7, null);
    for (final day in weekMacros) {
      dailyCalories[dayIndex(day.day)] = day.calories;
    }
    final loggedDayCount = weekMacros.length;
    final avgCalories = loggedDayCount == 0
        ? null
        : weekMacros.fold(0.0, (sum, d) => sum + d.calories) / loggedDayCount;

    final calorieGoal = settings.dailyCalorieGoal;
    final caloriesDaysMet =
        calorieGoal == null ? 0 : weekMacros.where((d) => d.calories <= calorieGoal).length;

    final stepGoal = settings.dailyStepGoal;
    final stepsDaysMet = stepGoal == null
        ? 0
        : dailySteps.where((s) => inWeek(s.date) && s.steps >= stepGoal).length;

    final waterGoal = settings.dailyWaterGoalLiters;
    var waterDaysMet = 0;
    if (waterGoal != null) {
      dailyWaterLiters.forEach((day, liters) {
        if (inWeek(day) && liters >= waterGoal) waterDaysMet++;
      });
    }

    return WeeklyRecap(
      weekStart: weekStart,
      workoutsDone: workoutsDone,
      workoutMinutes: workoutMinutes,
      avgCalories: avgCalories,
      loggedDayCount: loggedDayCount,
      calorieGoalSet: calorieGoal != null,
      caloriesDaysMet: caloriesDaysMet,
      stepGoalSet: stepGoal != null,
      stepsDaysMet: stepsDaysMet,
      waterGoalSet: waterGoal != null,
      waterDaysMet: waterDaysMet,
      weightStart: _latestWeightOnOrBefore(weights, weekStart),
      weightEnd: _latestWeightWithin(weights, weekStart, weekEnd),
      streaks: streaks,
      dailyCalories: dailyCalories,
      workoutDays: workoutDays,
    );
  }
}

DateTime _addDays(DateTime day, int n) => DateTime(day.year, day.month, day.day + n);

DateTime _localDay(DateTime dateTime) {
  final local = dateTime.toLocal();
  return DateTime(local.year, local.month, local.day);
}

double? _latestWeightOnOrBefore(List<WeightEntry> weights, DateTime cutoffInclusive) {
  WeightEntry? latest;
  for (final entry in weights) {
    final day = _localDay(entry.date);
    if (day.isAfter(cutoffInclusive)) continue;
    if (_isNewer(entry, day, latest)) latest = entry;
  }
  return latest?.weight;
}

double? _latestWeightWithin(List<WeightEntry> weights, DateTime start, DateTime endInclusive) {
  WeightEntry? latest;
  for (final entry in weights) {
    final day = _localDay(entry.date);
    if (day.isBefore(start) || day.isAfter(endInclusive)) continue;
    if (_isNewer(entry, day, latest)) latest = entry;
  }
  return latest?.weight;
}

/// Whether [entry] (on local day [day]) supersedes [current] — later day
/// wins, then later `recordedAt` on the same day — matching the tie-break
/// `_weightPoints` (`stat_chart_data.dart`) already uses.
bool _isNewer(WeightEntry entry, DateTime day, WeightEntry? current) {
  if (current == null) return true;
  final currentDay = _localDay(current.date);
  if (day.isAfter(currentDay)) return true;
  if (day.isBefore(currentDay)) return false;
  return entry.recordedAt.isAfter(current.recordedAt);
}
