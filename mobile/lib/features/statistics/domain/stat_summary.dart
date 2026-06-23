/// Aggregate figures for a [StatMetric] over a [StatsRange]'s chart points:
/// total, average, extremes, and how the more recent half of the range
/// trends against the earlier half.
class StatSummary {
  const StatSummary({
    required this.sum,
    required this.average,
    required this.min,
    required this.max,
    this.trend,
    this.trendPercent,
  });

  /// No points to summarize.
  static const empty = StatSummary(sum: 0, average: 0, min: 0, max: 0);

  final double sum;
  final double average;
  final double min;
  final double max;

  /// Signed delta between the later half's average and the earlier half's
  /// average within the range, or null when there isn't at least one point
  /// on each side of the range's midpoint to compare.
  final double? trend;

  /// [trend] expressed as a percentage of the earlier half's average, or
  /// null when that average is zero (would divide by zero) or [trend]
  /// itself is null.
  final double? trendPercent;
}
