import '../../../shared/widgets/charts/bar_chart.dart';
import '../../../shared/widgets/charts/time_series_chart.dart';
import '../domain/metric_summary.dart';
import '../domain/stat_metric.dart';
import 'stat_format.dart';

/// The bars of a statistics chart and how they are drawn.
class StatBars {
  const StatBars({required this.bars, required this.gap, this.weekly = false, this.averaged = false});

  final List<BarDatum> bars;
  final double gap;

  /// One bar per calendar week (sums) — the footnote explains the grouping.
  final bool weekly;

  /// One bar per week, but the mean of its days (a long span of a daily metric).
  final bool averaged;
}

/// Spans longer than this many days are drawn one bar per week — a bar per day
/// would be a hairline.
const int statMaxDailyBars = 100;

DateTime _key(DateTime d) => DateTime(d.year, d.month, d.day);

/// One bar per day from [from] to [today] — a day without a value is an empty
/// column, today is highlighted.
StatBars dailyBars({
  required StatMetric metric,
  required List<TimeSeriesPoint> points,
  required DateTime from,
  required DateTime today,
  required StatFormat fmt,
}) {
  final byDay = {for (final p in points) _key(p.date): p.value};
  final days = <DateTime>[];
  for (var d = _key(from); !d.isAfter(today); d = DateTime(d.year, d.month, d.day + 1)) {
    days.add(d);
  }
  if (days.length > statMaxDailyBars) return _weeklyAverages(metric: metric, points: points, from: from, today: today, fmt: fmt);

  final n = days.length;
  final f = fmt.f;
  final step = n <= 7 ? 1 : (n <= 35 ? 7 : 14);
  return StatBars(
    gap: n <= 7 ? 8 : (n <= 35 ? 3 : 1.5),
    bars: [
      for (final (i, d) in days.indexed)
        BarDatum(
          label: n <= 7
              ? f.weekdayNarrow(d)
              // Sparse: a date under every seventh (or fourteenth) bar, counted
              // from today so the newest bar is always labelled.
              : ((n - 1 - i) % step == 0 ? f.shortDate(d) : ''),
          value: byDay[d],
          highlighted: i == n - 1,
          semanticsLabel: n <= 12 && byDay[d] != null
              ? '${f.weekdayShort(d)}, ${fmt.withUnit(metric, byDay[d]!)}'
              : null,
        ),
    ],
  );
}

/// One bar per calendar week (Monday–Sunday) with the week's sum, the current
/// week last and highlighted.
StatBars weeklyBars({
  required StatMetric metric,
  required List<TimeSeriesPoint> points,
  required DateTime from,
  required DateTime today,
  required StatFormat fmt,
}) {
  final weeks = weeklySums(points, from: from, to: today);
  final n = weeks.length;
  final f = fmt.f;
  final step = n <= 12 ? 1 : (n <= 26 ? 2 : 4);
  return StatBars(
    weekly: true,
    gap: n <= 6 ? 14 : (n <= 12 ? 8 : 3),
    bars: [
      for (final (i, w) in weeks.indexed)
        BarDatum(
          label: (n - 1 - i) % step == 0 ? f.shortDate(w.weekStart) : '',
          value: w.value,
          highlighted: i == n - 1,
          semanticsLabel: n <= 12 ? '${f.shortDate(w.weekStart)}, ${fmt.withUnit(metric, w.value)}' : null,
        ),
    ],
  );
}

StatBars _weeklyAverages({
  required StatMetric metric,
  required List<TimeSeriesPoint> points,
  required DateTime from,
  required DateTime today,
  required StatFormat fmt,
}) {
  final first = weekStart(from);
  final last = weekStart(today);
  final sums = <DateTime, double>{};
  final counts = <DateTime, int>{};
  for (final p in points) {
    final k = weekStart(p.date);
    sums.update(k, (s) => s + p.value, ifAbsent: () => p.value);
    counts.update(k, (c) => c + 1, ifAbsent: () => 1);
  }
  final weeks = <DateTime>[];
  for (var w = first; !w.isAfter(last); w = DateTime(w.year, w.month, w.day + 7)) {
    weeks.add(w);
  }
  final n = weeks.length;
  final step = n <= 26 ? 4 : (n <= 60 ? 8 : 16);
  return StatBars(
    averaged: true,
    gap: n <= 60 ? 1.5 : 1,
    bars: [
      for (final (i, w) in weeks.indexed)
        BarDatum(
          label: (n - 1 - i) % step == 0 ? fmt.f.shortDate(w) : '',
          value: counts[w] == null ? null : sums[w]! / counts[w]!,
          highlighted: i == n - 1,
        ),
    ],
  );
}

/// The date the "all" range starts on: the oldest day that has a value.
DateTime? firstDay(List<TimeSeriesPoint> points) {
  if (points.isEmpty) return null;
  return points.map((p) => _key(p.date)).reduce((a, b) => a.isBefore(b) ? a : b);
}
