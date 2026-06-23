import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/charts/time_series_chart.dart';
import '../domain/stat_summary.dart';
import 'stat_chart_data.dart';

/// Summarizes the currently selected metric/range's chart points — sum,
/// average, min, max, and a trend — derived purely from
/// [statChartDataProvider]'s already-aggregated points. No further
/// repository reads: a true "previous calendar period" comparison would
/// need data outside the already-fetched range, so the trend instead splits
/// the existing points in half by date and compares the two halves.
final statSummaryProvider = Provider<AsyncValue<StatSummary>>((ref) {
  return ref.watch(statChartDataProvider).whenData(_summarize);
});

StatSummary _summarize(List<TimeSeriesPoint> points) {
  if (points.isEmpty) return StatSummary.empty;

  final values = points.map((p) => p.value).toList();
  final sum = values.fold(0.0, (a, b) => a + b);
  final average = sum / points.length;
  final min = values.reduce((a, b) => a < b ? a : b);
  final max = values.reduce((a, b) => a > b ? a : b);
  final trend = _trend(points);

  return StatSummary(
    sum: sum,
    average: average,
    min: min,
    max: max,
    trend: trend?.delta,
    trendPercent: trend?.percent,
  );
}

/// Splits the range in half by date — not by point count, since some days
/// may have no data — and compares the later half's average against the
/// earlier half's.
({double delta, double? percent})? _trend(List<TimeSeriesPoint> points) {
  if (points.length < 2) return null;

  final first = points.first.date;
  final last = points.last.date;
  if (!last.isAfter(first)) return null;

  final midpoint = first.add(last.difference(first) ~/ 2);
  final earlierHalf = points.where((p) => p.date.isBefore(midpoint)).toList();
  final laterHalf = points.where((p) => !p.date.isBefore(midpoint)).toList();
  if (earlierHalf.isEmpty || laterHalf.isEmpty) return null;

  final earlierAvg = earlierHalf.fold(0.0, (sum, p) => sum + p.value) / earlierHalf.length;
  final laterAvg = laterHalf.fold(0.0, (sum, p) => sum + p.value) / laterHalf.length;
  final delta = laterAvg - earlierAvg;
  final percent = earlierAvg == 0 ? null : delta / earlierAvg * 100;
  return (delta: delta, percent: percent);
}
