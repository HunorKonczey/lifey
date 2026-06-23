import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/charts/time_series_chart.dart';
import '../domain/weight_entry.dart';
import 'weight_controller.dart';
import 'weight_range.dart';

/// Derives the chart-ready series from the live weight entries: filtered to
/// the selected [WeightRange] and collapsed to one point per calendar day
/// (the most recently recorded entry that day), oldest first.
final weightChartDataProvider = Provider<AsyncValue<List<TimeSeriesPoint>>>((ref) {
  final entries = ref.watch(weightControllerProvider);
  final range = ref.watch(weightRangeControllerProvider);
  return entries.whenData((all) => _toChartPoints(all, range));
});

List<TimeSeriesPoint> _toChartPoints(List<WeightEntry> entries, WeightRange range) {
  final cutoff = range.cutoff();
  final inRange =
      cutoff == null ? entries : entries.where((e) => !e.date.isBefore(cutoff)).toList();

  // `entries` is already ordered date desc, recordedAt desc (see
  // WeightRepository.watchAll), so the first entry seen per calendar day is
  // the latest-recorded one for that day.
  final latestPerDay = <DateTime, WeightEntry>{};
  for (final entry in inRange) {
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    latestPerDay.putIfAbsent(day, () => entry);
  }

  final days = latestPerDay.keys.toList()..sort();
  return [
    for (final day in days) TimeSeriesPoint(date: day, value: latestPerDay[day]!.weight),
  ];
}
