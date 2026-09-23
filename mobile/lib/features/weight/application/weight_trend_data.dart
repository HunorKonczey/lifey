import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/charts/time_series_chart.dart';
import '../../onboarding/data/user_details_repository.dart';
import '../domain/weight_entry.dart';
import '../domain/weight_trend.dart';
import 'weight_chart_data.dart';
import 'weight_controller.dart';

/// The smoothed series for the weight chart, aligned index by index with
/// [weightChartDataProvider]'s points (docs/76-smarter-weight-trend-plan.md).
final weightTrendProvider = Provider<AsyncValue<List<double?>>>((ref) {
  return ref.watch(weightChartDataProvider).whenData(movingAverage);
});

/// The goal projection for the card above the chart.
///
/// Deliberately **not** derived from the chart's points: those are cut to the
/// selected range, and picking "week" must not shorten the history the rate is
/// measured over. It reads every entry instead, collapsed to one per day the
/// same way the chart does.
///
/// `null` whenever there is nothing to show — no goal weight, no entries, or a
/// goal the user hasn't set. `targetWeightKg` comes from the online-only
/// `/user-details` (D-W8), so offline this simply stays null and the card
/// hides; the trend line above it keeps working from the local DB.
final weightGoalProjectionProvider = Provider<WeightProjection?>((ref) {
  final goal = ref.watch(userDetailsProvider).value?.targetWeightKg;
  final entries = ref.watch(weightControllerProvider).value;
  if (goal == null || entries == null || entries.isEmpty) return null;

  final points = dailyPoints(entries);
  return projectGoal(points: points, trend: movingAverage(points), goalKg: goal);
});

/// One point per calendar day, oldest first — the most recently recorded
/// entry of each day, like the chart's own collapsing.
List<TimeSeriesPoint> dailyPoints(List<WeightEntry> entries) {
  // `entries` is ordered date desc, recordedAt desc (WeightRepository.watchAll),
  // so the first entry seen for a day is that day's latest recording.
  final latestPerDay = <DateTime, WeightEntry>{};
  for (final entry in entries) {
    final date = entry.date.toLocal();
    latestPerDay.putIfAbsent(DateTime(date.year, date.month, date.day), () => entry);
  }
  final days = latestPerDay.keys.toList()..sort();
  return [
    for (final day in days) TimeSeriesPoint(date: day, value: latestPerDay[day]!.weight),
  ];
}
