import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/charts/stats_range.dart';
import '../../../shared/widgets/charts/time_series_chart.dart';
import '../../nutrition/application/meal_controller.dart';
import '../../nutrition/domain/meal.dart';
import '../../steps/data/step_count_repository.dart';
import '../../steps/domain/daily_step_count.dart';
import '../../water/data/water_entry_repository.dart';
import '../../water/domain/water_entry.dart';
import '../../weight/application/weight_controller.dart';
import '../../weight/domain/weight_entry.dart';
import '../../workouts/application/workout_session_controller.dart';
import '../../workouts/domain/activity_type.dart';
import '../../workouts/domain/hr_zone_breakdown.dart';
import '../../workouts/domain/workout_session.dart';
import '../domain/stat_kind_filter.dart';
import '../domain/stat_metric.dart';
import 'stat_kind_filter_controller.dart';
import 'stat_metric_controller.dart';
import 'stats_range_controller.dart';

/// Derives the chart-ready series for the selected [StatMetric] + [StatsRange]
/// from the already-migrated feature repositories (meals, sessions, water,
/// weight) — the same local-first sources `dashboardControllerProvider`
/// combines for today's snapshot, here aggregated per day across a range.
/// No new repository: each branch only watches the one controller/stream the
/// selected metric actually needs.
final statChartDataProvider = Provider<AsyncValue<List<TimeSeriesPoint>>>((ref) {
  final metric = ref.watch(statMetricControllerProvider);
  final range = ref.watch(statsRangeControllerProvider);
  final kindFilter = ref.watch(statKindFilterControllerProvider);

  switch (metric) {
    case StatMetric.calories:
    case StatMetric.protein:
    case StatMetric.carbs:
    case StatMetric.fat:
      return ref.watch(mealControllerProvider).whenData((all) => _mealPoints(all, metric, range));
    // "edzés jellegű" (D-C3.4) — re-scoped to whichever kind is selected,
    // not just filtered out entirely under `strength`/`cardio` like the six
    // cardio-only metrics below are.
    case StatMetric.workoutMinutes:
    case StatMetric.workoutCount:
    case StatMetric.activeCalories:
      return ref.watch(workoutSessionControllerProvider).whenData(
          (all) => _sessionPoints(_filterByKind(all, kindFilter), metric, range));
    // Cardio-only metrics only ever contain cardio sessions regardless of
    // the filter — under `strength` there's nothing to show at all.
    case StatMetric.cardioDistance:
    case StatMetric.cardioMovingMinutes:
    case StatMetric.cardioElevationGain:
    case StatMetric.cardioSessions:
    case StatMetric.cardioHardZoneMinutes:
      return ref.watch(workoutSessionControllerProvider).whenData((all) =>
          kindFilter == StatKindFilter.strength ? const [] : _sessionPoints(all, metric, range));
    case StatMetric.cardioAvgPace:
      return ref.watch(workoutSessionControllerProvider).whenData((all) =>
          kindFilter == StatKindFilter.strength ? const [] : _cardioAvgPacePoints(all, range));
    case StatMetric.maxHeartRate:
      return ref.watch(workoutSessionControllerProvider).whenData((all) =>
          kindFilter == StatKindFilter.strength ? const [] : _maxHeartRatePoints(all, range));
    case StatMetric.water:
      return ref.watch(allWaterEntriesProvider).whenData((all) => _waterPoints(all, range));
    case StatMetric.weight:
      return ref.watch(weightControllerProvider).whenData((all) => _weightPoints(all, range));
    case StatMetric.steps:
      return ref.watch(allStepCountsProvider).whenData((all) => _stepsPoints(all, range));
  }
});

List<WorkoutSession> _filterByKind(List<WorkoutSession> sessions, StatKindFilter filter) {
  return switch (filter) {
    StatKindFilter.all => sessions,
    StatKindFilter.strength => sessions.where((s) => !s.isCardio).toList(),
    StatKindFilter.cardio => sessions.where((s) => s.isCardio).toList(),
  };
}

/// Which [StatMetric]s actually have at least one usable value, ever — not
/// range-filtered, since a metric with no data for *any* day (e.g.
/// activeCalories with no paired Apple Health workouts) would otherwise
/// always render to an empty chart no matter which range is selected. The
/// statistics screen uses this to hide such metrics from the picker instead
/// of letting the user select a perpetually-empty one.
final availableStatMetricsProvider = Provider<Set<StatMetric>>((ref) {
  final meals = ref.watch(mealControllerProvider).value ?? const [];
  final allSessions = ref.watch(workoutSessionControllerProvider).value ?? const [];
  final water = ref.watch(allWaterEntriesProvider).value ?? const [];
  final weights = ref.watch(weightControllerProvider).value ?? const [];
  // Same re-scoping `statChartDataProvider` applies (D-C3.4) — pre-filtering
  // here, rather than adding a separate `kindFilter` guard per metric below,
  // means every "edzés jellegű" predicate (including the six cardio-only
  // ones, which already only ever match cardio sessions) naturally reflects
  // the current filter for free: under `strength`, `sessions` holds no
  // cardio rows at all, so every cardio-only `any(...)` below is already
  // false without needing its own explicit filter check.
  final kindFilter = ref.watch(statKindFilterControllerProvider);
  final sessions = _filterByKind(allSessions, kindFilter);

  return {
    if (meals.isNotEmpty) ...[
      StatMetric.calories,
      StatMetric.protein,
      StatMetric.carbs,
      StatMetric.fat,
    ],
    if (sessions.isNotEmpty) StatMetric.workoutCount,
    if (sessions.any((s) => s.finishedAt != null)) StatMetric.workoutMinutes,
    if (sessions.any((s) => s.activeCalories != null)) StatMetric.activeCalories,
    if (sessions.any((s) => s.isCardio)) StatMetric.cardioSessions,
    if (sessions.any((s) => s.isCardio && s.movingSeconds != null))
      StatMetric.cardioMovingMinutes,
    if (sessions.any((s) =>
        s.isCardio &&
        (s.family == ActivityFamily.distance || s.family == ActivityFamily.machine) &&
        s.cardio?.distanceMeters != null))
      StatMetric.cardioDistance,
    if (sessions.any((s) =>
        s.isCardio && s.family == ActivityFamily.distance && s.cardio?.elevationGainMeters != null))
      StatMetric.cardioElevationGain,
    if (sessions.any((s) =>
        (s.activityType == 'RUNNING' || s.activityType == 'WALKING') &&
        s.movingSeconds != null &&
        (s.cardio?.distanceMeters ?? 0) > 0))
      StatMetric.cardioAvgPace,
    if (sessions.any((s) => s.isCardio && s.cardio?.maxHeartRate != null))
      StatMetric.maxHeartRate,
    // Offered only once some session actually carries zone data — which today
    // means a watch was involved. Without this gate the picker would list a
    // metric that charts a flat nothing for most users.
    if (sessions.any((s) => HrZoneBreakdown.fromSession(s) != null))
      StatMetric.cardioHardZoneMinutes,
    if (water.isNotEmpty) StatMetric.water,
    if (weights.isNotEmpty) StatMetric.weight,
    if (ref.watch(allStepCountsProvider).value?.isNotEmpty ?? false) StatMetric.steps,
  };
});

DateTime _localDay(DateTime dateTime) {
  final local = dateTime.toLocal();
  return DateTime(local.year, local.month, local.day);
}

List<TimeSeriesPoint> _pointsFromSums(Map<DateTime, double> sumsByDay) {
  final days = sumsByDay.keys.toList()..sort();
  return [for (final day in days) TimeSeriesPoint(date: day, value: sumsByDay[day]!)];
}

List<TimeSeriesPoint> _mealPoints(List<Meal> meals, StatMetric metric, StatsRange range) {
  final cutoff = range.cutoff();
  final sumsByDay = <DateTime, double>{};
  for (final meal in meals) {
    final day = _localDay(meal.dateTime);
    if (cutoff != null && day.isBefore(cutoff)) continue;
    final value = switch (metric) {
      StatMetric.calories => meal.totalCalories,
      StatMetric.protein => meal.totalProtein,
      StatMetric.carbs => meal.totalCarbs,
      StatMetric.fat => meal.totalFat,
      _ => 0.0,
    };
    sumsByDay.update(day, (sum) => sum + value, ifAbsent: () => value);
  }
  return _pointsFromSums(sumsByDay);
}

List<TimeSeriesPoint> _sessionPoints(
  List<WorkoutSession> sessions,
  StatMetric metric,
  StatsRange range,
) {
  final cutoff = range.cutoff();
  final sumsByDay = <DateTime, double>{};
  for (final session in sessions) {
    // Upcoming (not-yet-started) sessions aren't "workouts that happened" —
    // excluded the same way the backend excludes them from statistics.
    if (session.isUpcoming) continue;
    final startedAt = session.startedAt!;
    final day = _localDay(startedAt);
    if (cutoff != null && day.isBefore(cutoff)) continue;
    final value = switch (metric) {
      // Moving time, not wall-clock (docs/cardio/56-cardio-statistics-plan.md
      // D-C3.3): `effectiveDuration` is `movingSeconds` when set (cardio) or
      // falls back to `finishedAt - startedAt` (always the case for
      // STRENGTH, where `movingSeconds` is never set) — bit-identical to the
      // old `finishedAt?.difference(startedAt)` for every pre-cardio session.
      StatMetric.workoutMinutes => session.effectiveDuration?.inMinutes.toDouble(),
      StatMetric.workoutCount => 1.0,
      StatMetric.activeCalories => session.activeCalories,
      StatMetric.cardioSessions => session.isCardio ? 1.0 : null,
      StatMetric.cardioMovingMinutes =>
        (session.isCardio && session.movingSeconds != null)
            ? session.movingSeconds! / 60.0
            : null,
      // DISTANCE + MACHINE (56 §3) — an indoor bike's odometer counts too,
      // hiking/running/walking distance from GPS.
      StatMetric.cardioDistance => (session.isCardio &&
              (session.family == ActivityFamily.distance ||
                  session.family == ActivityFamily.machine) &&
              session.cardio?.distanceMeters != null)
          ? session.cardio!.distanceMeters! / 1000.0
          : null,
      // DISTANCE only (56 §3) — an indoor bike gains no real elevation even
      // though the column exists for it.
      StatMetric.cardioElevationGain => (session.isCardio &&
              session.family == ActivityFamily.distance &&
              session.cardio?.elevationGainMeters != null)
          ? session.cardio!.elevationGainMeters!
          : null,
      // Zones come from the watch, so this is where a GAME session finally
      // contributes something of its own to the statistics: a match has no
      // distance, no elevation and no pace, but it does have zone time
      // (docs/cardio/60 C9.5). Every cardio family is counted — the metric is
      // about heart rate, not about which sport produced it.
      //
      // Read through [HrZoneBreakdown] rather than adding the two columns
      // straight up, so the chart inherits the same cap the panel uses: a row
      // where the watch and the phone both wrote zones can total more time
      // than the session lasted (docs/cardio/60 §9), and an uncapped sum here
      // would quietly inflate a week's training load.
      StatMetric.cardioHardZoneMinutes => _hardZoneMinutes(session),
      _ => null,
    };
    if (value == null) continue;
    sumsByDay.update(day, (sum) => sum + value, ifAbsent: () => value);
  }
  return _pointsFromSums(sumsByDay);
}

/// D-C3.6 (docs/cardio/56-cardio-statistics-plan.md): each day's pace is
/// Σ moving time / Σ distance across that day's sessions, not the arithmetic
/// mean of each session's own pace — a 1 km jog and a 20 km run on the same
/// day must not count equally. Scoped to running/walking specifically, not
/// the whole DISTANCE family (which also includes hiking): 56 §3's own
/// parenthetical ("futás, séta") excludes hiking on purpose — stops for
/// photos/rest make its pace not a meaningful "how fast was I" number.
///
/// A day only gets a point once at least one qualifying session has a real
/// (`> 0`) distance — zero/missing distance never contributes to either sum,
/// so the division below can't hit zero, and a day with nothing usable is
/// simply absent (missing, not a 0:00/km point) rather than crashing or
/// lying, matching D-C3.5's "missing, not zero" rule for cardio metrics.
/// Minutes at zone 4+5, or null when this session measured no zones at all.
/// Zero is a real answer (an easy session that never reached threshold) and is
/// charted as such; *no data* is not, and stays out of the day's sum.
double? _hardZoneMinutes(WorkoutSession session) {
  if (!session.isCardio) return null;
  final breakdown = HrZoneBreakdown.fromSession(session);
  if (breakdown == null) return null;
  return (breakdown.secondsIn(4) + breakdown.secondsIn(5)) / 60.0;
}

List<TimeSeriesPoint> _cardioAvgPacePoints(List<WorkoutSession> sessions, StatsRange range) {
  final cutoff = range.cutoff();
  final secondsByDay = <DateTime, double>{};
  final metersByDay = <DateTime, double>{};
  for (final session in sessions) {
    if (session.isUpcoming) continue;
    if (session.activityType != 'RUNNING' && session.activityType != 'WALKING') continue;
    final seconds = session.movingSeconds;
    final meters = session.cardio?.distanceMeters;
    if (seconds == null || meters == null || meters <= 0) continue;
    final day = _localDay(session.startedAt!);
    if (cutoff != null && day.isBefore(cutoff)) continue;
    secondsByDay.update(day, (s) => s + seconds, ifAbsent: () => seconds.toDouble());
    metersByDay.update(day, (m) => m + meters, ifAbsent: () => meters);
  }
  final days = secondsByDay.keys.toList()..sort();
  return [
    for (final day in days)
      TimeSeriesPoint(
        date: day,
        value: (secondsByDay[day]! / 60.0) / (metersByDay[day]! / 1000.0),
      ),
  ];
}

/// Each day's point is that day's *highest* recorded max heart rate across
/// its cardio sessions — [StatMetric.maxHeartRate]'s `average` aggregation
/// then means "average of daily maximums" (56 §3) for free, once the
/// statistics screen's generic sum/average/min/max summary
/// (`stat_summary_data.dart`) runs over these already-per-day-maxed points.
List<TimeSeriesPoint> _maxHeartRatePoints(List<WorkoutSession> sessions, StatsRange range) {
  final cutoff = range.cutoff();
  final maxByDay = <DateTime, double>{};
  for (final session in sessions) {
    if (session.isUpcoming || !session.isCardio) continue;
    final heartRate = session.cardio?.maxHeartRate;
    if (heartRate == null) continue;
    final day = _localDay(session.startedAt!);
    if (cutoff != null && day.isBefore(cutoff)) continue;
    final current = maxByDay[day];
    if (current == null || heartRate > current) maxByDay[day] = heartRate;
  }
  return _pointsFromSums(maxByDay);
}

List<TimeSeriesPoint> _waterPoints(List<WaterEntry> entries, StatsRange range) {
  final cutoff = range.cutoff();
  final sumsByDay = <DateTime, double>{};
  for (final entry in entries) {
    final day = _localDay(entry.consumedAt);
    if (cutoff != null && day.isBefore(cutoff)) continue;
    sumsByDay.update(day, (sum) => sum + entry.volumeLiters, ifAbsent: () => entry.volumeLiters);
  }
  return _pointsFromSums(sumsByDay);
}

List<TimeSeriesPoint> _stepsPoints(List<DailyStepCount> counts, StatsRange range) {
  final cutoff = range.cutoff();
  final days = counts
      .where((c) => cutoff == null || !c.date.isBefore(cutoff))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return [for (final c in days) TimeSeriesPoint(date: c.date, value: c.steps.toDouble())];
}

/// One point per calendar day — the most recently recorded entry that day —
/// matching `weight_chart_data.dart`'s `_toChartPoints` (kept separate since
/// the weight chart still drives off the weight-specific [WeightRange]).
List<TimeSeriesPoint> _weightPoints(List<WeightEntry> entries, StatsRange range) {
  final cutoff = range.cutoff();
  final inRange =
      cutoff == null ? entries : entries.where((e) => !e.date.isBefore(cutoff)).toList();

  // `entries` is already ordered date desc, recordedAt desc (see
  // WeightRepository.watchAll), so the first entry seen per calendar day is
  // the latest-recorded one for that day.
  final latestPerDay = <DateTime, WeightEntry>{};
  for (final entry in inRange) {
    latestPerDay.putIfAbsent(_localDay(entry.date), () => entry);
  }

  final days = latestPerDay.keys.toList()..sort();
  return [for (final day in days) TimeSeriesPoint(date: day, value: latestPerDay[day]!.weight)];
}
