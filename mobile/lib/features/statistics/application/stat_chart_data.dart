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
import '../../workouts/domain/workout_session.dart';
import '../domain/stat_metric.dart';
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

  switch (metric) {
    case StatMetric.calories:
    case StatMetric.protein:
    case StatMetric.carbs:
    case StatMetric.fat:
      return ref.watch(mealControllerProvider).whenData((all) => _mealPoints(all, metric, range));
    case StatMetric.workoutMinutes:
    case StatMetric.workoutCount:
    case StatMetric.activeCalories:
      return ref
          .watch(workoutSessionControllerProvider)
          .whenData((all) => _sessionPoints(all, metric, range));
    case StatMetric.water:
      return ref.watch(allWaterEntriesProvider).whenData((all) => _waterPoints(all, range));
    case StatMetric.weight:
      return ref.watch(weightControllerProvider).whenData((all) => _weightPoints(all, range));
    case StatMetric.steps:
      return ref.watch(allStepCountsProvider).whenData((all) => _stepsPoints(all, range));
  }
});

/// Which [StatMetric]s actually have at least one usable value, ever — not
/// range-filtered, since a metric with no data for *any* day (e.g.
/// activeCalories with no paired Apple Health workouts) would otherwise
/// always render to an empty chart no matter which range is selected. The
/// statistics screen uses this to hide such metrics from the picker instead
/// of letting the user select a perpetually-empty one.
final availableStatMetricsProvider = Provider<Set<StatMetric>>((ref) {
  final meals = ref.watch(mealControllerProvider).value ?? const [];
  final sessions = ref.watch(workoutSessionControllerProvider).value ?? const [];
  final water = ref.watch(allWaterEntriesProvider).value ?? const [];
  final weights = ref.watch(weightControllerProvider).value ?? const [];

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
    final finishedAt = session.finishedAt;
    final value = switch (metric) {
      // Skip in-progress sessions: there's no finished duration to sum yet.
      StatMetric.workoutMinutes =>
        finishedAt?.difference(startedAt).inMinutes.toDouble(),
      StatMetric.workoutCount => 1.0,
      StatMetric.activeCalories => session.activeCalories,
      _ => null,
    };
    if (value == null) continue;
    sumsByDay.update(day, (sum) => sum + value, ifAbsent: () => value);
  }
  return _pointsFromSums(sumsByDay);
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
