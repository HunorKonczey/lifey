import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nutrition/application/daily_macros_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../steps/data/step_count_repository.dart';
import '../../water/application/daily_water_totals_provider.dart';
import '../../workouts/application/workout_session_controller.dart';
import '../../workouts/domain/workout_session.dart';
import '../domain/streak.dart';

/// A day meets the workout streak once it has a STRENGTH session (any
/// length) *or* a cardio session with at least this many moving seconds —
/// docs/cardio/51-cardio-overview-plan.md §8 Q1, decided: "≥ 15 perc
/// mozgásidőtől (`moving_seconds ≥ 900`)... **Nem beállítás**." A single
/// named constant, not a `UserSettings` field — there is deliberately no way
/// to configure this from the app.
const workoutStreakMovingSecondsThreshold = 900;

DateTime _localToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _localDay(DateTime dateTime) {
  final local = dateTime.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Whether [session] alone is enough to meet the workout streak for the day
/// it happened on (see [workoutStreakMovingSecondsThreshold]'s doc) — a
/// STRENGTH session always counts, a cardio session only once its *moving*
/// time (not gross wall-clock duration, matching D-C3.3 everywhere else)
/// clears the threshold.
bool _meetsWorkoutStreak(WorkoutSession session) {
  if (!session.isCardio) return true;
  return (session.movingSeconds ?? 0) >= workoutStreakMovingSecondsThreshold;
}

/// One [Streak] per daily goal that's actually set (calories/steps/water),
/// derived from the same local-first sources the dashboard already watches.
///
/// A plain derived [Provider], not a [StreamProvider] — like
/// `dashboardControllerProvider`, it recomputes synchronously whenever any
/// watched source changes, reading `.value` off each underlying stream so a
/// still-loading source contributes nothing yet rather than blocking the
/// whole list. Nothing here is persisted: a miss, a retro-edited meal, or a
/// late-arriving HealthKit import simply changes what this recomputes to.
final streaksProvider = Provider<List<Streak>>((ref) {
  final settings = ref.watch(settingsControllerProvider).value;
  if (settings == null) return const [];

  final today = _localToday();
  final streaks = <Streak>[];

  final calorieGoal = settings.dailyCalorieGoal;
  if (calorieGoal != null) {
    final days = ref.watch(dailyMacrosProvider).value ?? const [];
    streaks.add(_computeStreak(
      metric: StreakMetric.calories,
      today: today,
      // A day only counts as "met" once a meal was logged for it — every
      // entry in `days` already represents a logged meal (watchDailyMacros
      // creates the bucket even for a zero-entry meal), so presence in the
      // list is exactly that signal; an unlogged day must never look like a
      // free win just because 0 <= any calorie goal.
      isMet: (day) => day.calories <= calorieGoal,
      dayOf: (day) => day.day,
      source: days,
    ));
  }

  final stepGoal = settings.dailyStepGoal;
  if (stepGoal != null) {
    final counts = ref.watch(allStepCountsProvider).value ?? const [];
    streaks.add(_computeStreak(
      metric: StreakMetric.steps,
      today: today,
      isMet: (count) => count.steps >= stepGoal,
      // Already one local-midnight row per day at write time
      // (StepCountRepository.upsertForDay) — no `.toLocal()` needed, same
      // convention `stat_chart_data.dart`'s `_stepsPoints` follows.
      dayOf: (count) => count.date,
      source: counts,
    ));
  }

  final waterGoal = settings.dailyWaterGoalLiters;
  if (waterGoal != null) {
    final totals = ref.watch(dailyWaterTotalsProvider).value ?? const {};
    streaks.add(_computeStreak(
      metric: StreakMetric.water,
      today: today,
      isMet: (entry) => entry.value >= waterGoal,
      dayOf: (entry) => entry.key,
      source: totals.entries,
    ));
  }

  // Unconditional — unlike the three above, there's no goal to gate this on
  // (Q1: "Nem beállítás"). Pre-aggregated into one met/unmet bool per day
  // first (mirroring the water branch's already-per-day `totals` map)
  // because, unlike the sources above, a day can have *multiple* sessions —
  // `_computeStreak`'s per-item loop assumes at most one relevant reading
  // per day and would let a later unmet session silently overwrite an
  // earlier met one for `todayMet` if fed raw sessions directly.
  final sessions = ref.watch(workoutSessionControllerProvider).value ?? const [];
  final workoutMetByDay = <DateTime, bool>{};
  for (final session in sessions) {
    if (session.isUpcoming || session.startedAt == null) continue;
    final day = _localDay(session.startedAt!);
    workoutMetByDay[day] = (workoutMetByDay[day] ?? false) || _meetsWorkoutStreak(session);
  }
  streaks.add(_computeStreak(
    metric: StreakMetric.workout,
    today: today,
    isMet: (entry) => entry.value,
    dayOf: (entry) => entry.key,
    source: workoutMetByDay.entries,
  ));

  return streaks;
});

/// Shared plumbing for the three branches above: splits [source] into past
/// met-days vs today's met state, then hands both to [Streak.compute].
Streak _computeStreak<T>({
  required StreakMetric metric,
  required DateTime today,
  required bool Function(T) isMet,
  required DateTime Function(T) dayOf,
  required Iterable<T> source,
}) {
  final metDays = <DateTime>{};
  var todayMet = false;

  for (final item in source) {
    final day = dayOf(item);
    final met = isMet(item);
    if (day == today) {
      todayMet = met;
    } else if (day.isBefore(today) && met) {
      metDays.add(day);
    }
  }

  return Streak.compute(metric: metric, metDays: metDays, todayMet: todayMet, today: today);
}
