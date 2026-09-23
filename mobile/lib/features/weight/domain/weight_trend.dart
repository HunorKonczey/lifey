import '../../../shared/widgets/charts/time_series_chart.dart';

/// The 7-day moving average and the goal projection behind it
/// (docs/76-smarter-weight-trend-plan.md). Pure functions over points the
/// caller already has — nothing here reads a repository, so every rule below
/// is testable without a database.

/// How many days of history one trend value averages (D-W1).
const int trendWindowDays = 7;

/// Fewer entries than this in a window and there is nothing to average (D-W2).
const int minEntriesPerWindow = 2;

/// How far back the rate is measured (D-W5).
const int rateWindowDays = 28;

/// The projection needs at least this many trend days, spanning at least
/// [minProjectionSpanDays], before it will name a date (D-W6).
const int minProjectionPoints = 4;
const int minProjectionSpanDays = 14;

/// Closer than this to the goal and the goal counts as reached.
const double goalReachedToleranceKg = 0.2;

/// Beyond this the estimate stops being an estimate.
const int maxProjectionDays = 730;

/// The trailing [trendWindowDays]-day mean for each point, aligned index by
/// index with [points]; `null` where the window holds fewer than
/// [minEntriesPerWindow] entries.
///
/// The window is measured in **days, not samples** (D-W1): people skip
/// weigh-ins, and averaging "the last seven entries" over a gappy month would
/// report a weekly figure covering three weeks.
List<double?> movingAverage(List<TimeSeriesPoint> points, {int windowDays = trendWindowDays}) {
  final trend = List<double?>.filled(points.length, null);
  for (var i = 0; i < points.length; i++) {
    final windowStart = points[i].date.subtract(Duration(days: windowDays - 1));
    var sum = 0.0;
    var count = 0;
    // Points are oldest-first, so walking back stops as soon as we leave the
    // window.
    for (var j = i; j >= 0; j--) {
      if (points[j].date.isBefore(windowStart)) break;
      sum += points[j].value;
      count++;
    }
    if (count >= minEntriesPerWindow) trend[i] = sum / count;
  }
  return trend;
}

/// Why the projection is not naming a date, or that it is.
enum WeightProjectionState {
  /// Moving toward the goal; [WeightProjection.etaDate] is set.
  onTrack,

  /// Within [goalReachedToleranceKg] of the goal.
  reached,

  /// The trend is moving away from the goal.
  wrongWay,

  /// Toward the goal, but slower than [maxProjectionDays] allows for.
  tooSlow,

  /// Not enough trend yet to say anything (D-W6).
  notEnoughData,
}

/// What the goal card shows (docs/76 §4). [kgPerWeek] is signed the way the
/// scale moves: negative while losing.
class WeightProjection {
  const WeightProjection({
    required this.state,
    required this.goalKg,
    required this.currentKg,
    required this.remainingKg,
    this.kgPerWeek,
    this.etaDate,
  });

  final WeightProjectionState state;
  final double goalKg;

  /// The trend's latest value — not the last raw weigh-in (D-W4).
  final double currentKg;

  /// How far the goal still is, always non-negative.
  final double remainingKg;

  /// Null only when there was not enough data to measure a rate.
  final double? kgPerWeek;
  final DateTime? etaDate;
}

/// Projects when [trend] would reach [goalKg], reading the smoothed series
/// rather than the raw weigh-ins (D-W4).
///
/// [trend] is [movingAverage]'s output beside the points it was derived from;
/// `null` entries are skipped. Returns null when there is no trend at all —
/// the caller hides the card rather than showing an empty one.
WeightProjection? projectGoal({
  required List<TimeSeriesPoint> points,
  required List<double?> trend,
  required double goalKg,
  DateTime? now,
}) {
  final series = <TimeSeriesPoint>[
    for (var i = 0; i < points.length && i < trend.length; i++)
      if (trend[i] != null) TimeSeriesPoint(date: points[i].date, value: trend[i]!),
  ];
  if (series.isEmpty) return null;

  final current = series.last.value;
  final remaining = (current - goalKg).abs();
  if (remaining <= goalReachedToleranceKg) {
    return WeightProjection(
      state: WeightProjectionState.reached,
      goalKg: goalKg,
      currentKg: current,
      remainingKg: remaining,
    );
  }

  final recent = _lastDays(series, rateWindowDays);
  final spanDays = recent.isEmpty
      ? 0
      : recent.last.date.difference(recent.first.date).inDays;
  if (recent.length < minProjectionPoints || spanDays < minProjectionSpanDays) {
    return WeightProjection(
      state: WeightProjectionState.notEnoughData,
      goalKg: goalKg,
      currentKg: current,
      remainingKg: remaining,
    );
  }

  final kgPerDay = _slopePerDay(recent);
  final kgPerWeek = kgPerDay * 7;
  final towardGoal = goalKg < current ? kgPerDay < 0 : kgPerDay > 0;
  if (!towardGoal || kgPerDay == 0) {
    return WeightProjection(
      state: WeightProjectionState.wrongWay,
      goalKg: goalKg,
      currentKg: current,
      remainingKg: remaining,
      kgPerWeek: kgPerWeek,
    );
  }

  final days = (remaining / kgPerDay.abs()).ceil();
  if (days > maxProjectionDays) {
    return WeightProjection(
      state: WeightProjectionState.tooSlow,
      goalKg: goalKg,
      currentKg: current,
      remainingKg: remaining,
      kgPerWeek: kgPerWeek,
    );
  }

  final from = now ?? DateTime.now();
  return WeightProjection(
    state: WeightProjectionState.onTrack,
    goalKg: goalKg,
    currentKg: current,
    remainingKg: remaining,
    kgPerWeek: kgPerWeek,
    etaDate: DateTime(from.year, from.month, from.day).add(Duration(days: days)),
  );
}

List<TimeSeriesPoint> _lastDays(List<TimeSeriesPoint> series, int days) {
  final from = series.last.date.subtract(Duration(days: days - 1));
  return series.where((p) => !p.date.isBefore(from)).toList();
}

/// Least-squares slope in kg/day (D-W5) — x is days since the first point.
double _slopePerDay(List<TimeSeriesPoint> series) {
  final origin = series.first.date;
  final xs = [for (final p in series) p.date.difference(origin).inDays.toDouble()];
  final meanX = xs.reduce((a, b) => a + b) / xs.length;
  final meanY = series.map((p) => p.value).reduce((a, b) => a + b) / series.length;

  var numerator = 0.0;
  var denominator = 0.0;
  for (var i = 0; i < series.length; i++) {
    final dx = xs[i] - meanX;
    numerator += dx * (series[i].value - meanY);
    denominator += dx * dx;
  }
  // Every sample on the same day: no slope to measure.
  return denominator == 0 ? 0 : numerator / denominator;
}
