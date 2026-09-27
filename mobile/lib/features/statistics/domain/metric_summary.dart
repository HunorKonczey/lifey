import '../../../shared/widgets/charts/time_series_chart.dart';
import 'stat_metric.dart';

/// What the statistics screen says about one [StatMetric] over a range: one
/// hero number, its trend against the period before, and up to three side
/// stats that mean something *for that metric* — no "Total" for weight, a
/// weekly average for workouts (docs/redesign/77-mobile-redesign-plan.md R4.5,
/// canvas Lifey 4 › 5). A pure function of the series, so every rule below is
/// testable without a database.

/// What the hero number is.
enum StatHeroKind {
  /// Mean of the days that have a value ("Daily average · last 30 days").
  dailyAverage,

  /// The newest reading (weight).
  latest,

  /// The sum over the range (minutes, distance, elevation, hard-zone minutes).
  total,

  /// How many happened (workouts, cardio sessions).
  count,

  /// The peak of the range (max heart rate, highest altitude).
  highest,

  /// Σ time / Σ distance over the range — not the mean of daily paces.
  weightedPace,
}

/// How the metric is charted.
enum StatChartKind {
  /// One bar per day, with the goal as a dashed line where there is one.
  dailyBars,

  /// One bar per calendar week (Monday–Sunday), the current week last and
  /// highlighted — so a single day never looks like a spike.
  weeklyBars,

  /// A line over the days (steps, weight, pace, heart rate).
  line,
}

/// One of the side stats under the chart.
enum StatSideKind {
  lowest,
  highest,
  daysOnTarget,
  daysAtGoal,
  total,
  changeInPeriod,
  perWeek,
  mostInAWeek,
  totalTime,
  avgPerWorkout,
  avgPerSession,
  longest,
  highestSession,
  fastest,
  slowest,
  averageOfMaxima,
}

/// How a side stat's number is written.
enum StatValueKind {
  /// In the metric's own unit ("3 140 steps", "1.2 L").
  metric,

  /// A number of days ("18 days").
  days,

  /// Minutes as a duration ("23 h 40", "72 min").
  duration,

  /// A plain count ("6").
  count,

  /// Distance in kilometres.
  distance,

  /// Minutes per kilometre, written M:SS.
  pace,

  /// A signed change in the metric's unit ("−1.4 kg").
  signedMetric,
}

class StatSide {
  const StatSide(this.kind, this.value, this.valueKind);

  final StatSideKind kind;
  final double value;
  final StatValueKind valueKind;
}

/// The change against the period before it, both of the same length.
class PeriodTrend {
  const PeriodTrend({required this.delta, this.percent});

  /// Current minus prior, in the metric's unit.
  final double delta;

  /// [delta] as a share of the prior value; null when the prior value is 0
  /// (there is no "∞ %").
  final double? percent;
}

/// The series behind a summary: one point per day that has a value, oldest
/// first, plus what per-day points cannot say.
class StatSeries {
  const StatSeries({required this.points, this.samples = const [], this.weights = const {}});

  /// Copy holding only what falls on a day in `[from, to)` — either end open —
  /// so one long series is cut into the range and the period before it.
  StatSeries window({DateTime? from, DateTime? to}) {
    bool inside(DateTime d) => (from == null || !d.isBefore(from)) && (to == null || d.isBefore(to));
    return StatSeries(
      points: [for (final p in points) if (inside(p.date)) p],
      samples: [for (final s in samples) if (inside(s.date)) s],
      weights: {for (final e in weights.entries) if (inside(e.key)) e.key: e.value},
    );
  }

  static const empty = StatSeries(points: []);

  final List<TimeSeriesPoint> points;

  /// One value per *session* (minutes, km, metres), dated, for the
  /// session-based metrics — "longest" and "average per workout" need them, and
  /// a day with two workouts is one point.
  final List<TimeSeriesPoint> samples;

  List<double> get sampleValues => [for (final s in samples) s.value];

  /// Per-day weight of a pace point (the day's kilometres), so the range's
  /// pace is Σ time / Σ distance rather than a mean of means.
  final Map<DateTime, double> weights;

  bool get isEmpty => points.isEmpty;
}

/// The goals a summary compares days against; null = not set.
class StatGoals {
  const StatGoals({this.calories, this.protein, this.carbs, this.fat, this.waterLiters});

  static const none = StatGoals();

  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? waterLiters;
}

class MetricSummary {
  const MetricSummary({
    required this.heroKind,
    required this.chartKind,
    required this.sides,
    this.hero,
    this.trend,
    this.perWeek,
  });

  final StatHeroKind heroKind;
  final StatChartKind chartKind;

  /// Null when there is nothing to summarise.
  final double? hero;

  /// Against the period before; null when that period has no data or the
  /// range is "all".
  final PeriodTrend? trend;

  /// Events per week, for the metrics that count events (the "5.1 / week"
  /// chip); null otherwise.
  final double? perWeek;

  /// Up to three, in display order.
  final List<StatSide> sides;
}

/// How [metric] is charted.
StatChartKind chartKindFor(StatMetric metric) => switch (metric) {
      StatMetric.calories ||
      StatMetric.protein ||
      StatMetric.carbs ||
      StatMetric.fat ||
      StatMetric.water ||
      StatMetric.activeCalories =>
        StatChartKind.dailyBars,
      StatMetric.workoutCount ||
      StatMetric.workoutMinutes ||
      StatMetric.cardioSessions ||
      StatMetric.cardioDistance ||
      StatMetric.cardioMovingMinutes ||
      StatMetric.cardioElevationGain ||
      StatMetric.cardioHardZoneMinutes =>
        StatChartKind.weeklyBars,
      StatMetric.steps ||
      StatMetric.weight ||
      StatMetric.cardioAvgPace ||
      StatMetric.maxHeartRate ||
      StatMetric.cardioMaxAltitude =>
        StatChartKind.line,
    };

/// Metrics whose day is a running total that is still growing today — an
/// unfinished day understates it, so the day-based figures (average, lowest,
/// highest, trend) leave today out. Events that already happened (a workout,
/// a run) are complete and count.
bool isRunningDailyTotal(StatMetric metric) => switch (metric) {
      StatMetric.calories ||
      StatMetric.protein ||
      StatMetric.carbs ||
      StatMetric.fat ||
      StatMetric.water ||
      StatMetric.steps ||
      StatMetric.activeCalories =>
        true,
      _ => false,
    };

/// Calories count as "on target" within this share of the goal either way.
const double calorieTargetTolerance = 0.10;

/// The first day (Monday) of [date]'s calendar week.
DateTime weekStart(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));
}

/// Sum per calendar week, oldest first, **including weeks with nothing** — a
/// missing week is a zero, not a gap — from the week of [from] to the week of
/// [to]. The two ends are whole calendar weeks: a week is never cut in half by
/// the range's own edge.
List<({DateTime weekStart, double value})> weeklySums(
  List<TimeSeriesPoint> points, {
  required DateTime from,
  required DateTime to,
}) {
  final first = weekStart(from);
  final last = weekStart(to);
  final sums = <DateTime, double>{};
  for (final p in points) {
    final key = weekStart(p.date);
    if (key.isBefore(first) || key.isAfter(last)) continue;
    sums.update(key, (s) => s + p.value, ifAbsent: () => p.value);
  }
  final weeks = <({DateTime weekStart, double value})>[];
  for (var w = first; !w.isAfter(last); w = DateTime(w.year, w.month, w.day + 7)) {
    weeks.add((weekStart: w, value: sums[w] ?? 0));
  }
  return weeks;
}

/// The summary of [metric].
///
/// [current] holds the range's own days (`today − (rangeDays − 1)` … today);
/// [prior] the [rangeDays] days before them, or null when the range is "all",
/// the history window of the plan cuts it, or there is none. [rangeDays] is
/// null for "all" (then [current] spans the whole history).
MetricSummary summaryFor(
  StatMetric metric, {
  required StatSeries current,
  StatSeries? prior,
  required DateTime today,
  int? rangeDays,
  StatGoals goals = StatGoals.none,
}) {
  final day = DateTime(today.year, today.month, today.day);
  final chartKind = chartKindFor(metric);

  // The days the day-based figures are computed over.
  List<TimeSeriesPoint> days(StatSeries s) {
    if (!isRunningDailyTotal(metric)) return s.points;
    final complete = s.points.where((p) => p.date.isBefore(day)).toList();
    return complete.isEmpty ? s.points : complete;
  }

  final points = days(current);
  final values = [for (final p in points) p.value];
  final priorPoints = prior == null ? const <TimeSeriesPoint>[] : days(prior);

  MetricSummary empty(StatHeroKind kind) =>
      MetricSummary(heroKind: kind, chartKind: chartKind, sides: const []);

  double sum(Iterable<double> v) => v.fold(0.0, (a, b) => a + b);
  double mean(List<double> v) => v.isEmpty ? 0 : sum(v) / v.length;
  double minOf(List<double> v) => v.reduce((a, b) => a < b ? a : b);
  double maxOf(List<double> v) => v.reduce((a, b) => a > b ? a : b);

  // Number of weeks the range spans, for "per week".
  final weeks = rangeDays != null
      ? rangeDays / 7
      : (current.points.isEmpty
              ? 0
              : (current.points.last.date.difference(current.points.first.date).inDays + 1) / 7)
          .toDouble();
  double? perWeek(double total) => weeks > 0 ? total / weeks : null;

  double mostInAWeek() {
    final from = rangeDays != null ? DateTime(day.year, day.month, day.day - (rangeDays - 1)) : current.points.first.date;
    final w = weeklySums(current.points, from: from, to: day);
    return w.isEmpty ? 0 : maxOf([for (final e in w) e.value]);
  }

  PeriodTrend? trendOf(double? now, double? before, {bool percent = true}) {
    if (prior == null || priorPoints.isEmpty || now == null || before == null) return null;
    return PeriodTrend(delta: now - before, percent: percent && before != 0 ? (now - before) / before * 100 : null);
  }

  double? avgOrNull(List<TimeSeriesPoint> p) => p.isEmpty ? null : mean([for (final e in p) e.value]);
  double? sumOrNull(List<TimeSeriesPoint> p) => p.isEmpty ? null : sum([for (final e in p) e.value]);

  switch (metric) {
    case StatMetric.calories:
    case StatMetric.protein:
    case StatMetric.carbs:
    case StatMetric.fat:
    case StatMetric.water:
      if (values.isEmpty) return empty(StatHeroKind.dailyAverage);
      final goal = switch (metric) {
        StatMetric.calories => goals.calories,
        StatMetric.protein => goals.protein,
        StatMetric.carbs => goals.carbs,
        StatMetric.fat => goals.fat,
        _ => goals.waterLiters,
      };
      final third = goal == null
          ? null
          : metric == StatMetric.calories
              ? StatSide(
                  StatSideKind.daysOnTarget,
                  values.where((v) => (v - goal).abs() <= goal * calorieTargetTolerance).length.toDouble(),
                  StatValueKind.days,
                )
              : StatSide(StatSideKind.daysAtGoal, values.where((v) => v >= goal).length.toDouble(), StatValueKind.days);
      return MetricSummary(
        heroKind: StatHeroKind.dailyAverage,
        chartKind: chartKind,
        hero: mean(values),
        trend: trendOf(mean(values), avgOrNull(priorPoints)),
        sides: [
          StatSide(StatSideKind.lowest, minOf(values), StatValueKind.metric),
          StatSide(StatSideKind.highest, maxOf(values), StatValueKind.metric),
          if (third != null) third,
        ],
      );

    case StatMetric.steps:
      if (values.isEmpty) return empty(StatHeroKind.dailyAverage);
      return MetricSummary(
        heroKind: StatHeroKind.dailyAverage,
        chartKind: chartKind,
        hero: mean(values),
        trend: trendOf(mean(values), avgOrNull(priorPoints)),
        sides: [
          StatSide(StatSideKind.lowest, minOf(values), StatValueKind.metric),
          StatSide(StatSideKind.highest, maxOf(values), StatValueKind.metric),
          StatSide(StatSideKind.total, sum(values), StatValueKind.metric),
        ],
      );

    case StatMetric.activeCalories:
      if (values.isEmpty) return empty(StatHeroKind.dailyAverage);
      return MetricSummary(
        heroKind: StatHeroKind.dailyAverage,
        chartKind: chartKind,
        hero: mean(values),
        trend: trendOf(mean(values), avgOrNull(priorPoints)),
        sides: [
          StatSide(StatSideKind.highest, maxOf(values), StatValueKind.metric),
          StatSide(StatSideKind.total, sum(values), StatValueKind.metric),
        ],
      );

    case StatMetric.weight:
      if (values.isEmpty) return empty(StatHeroKind.latest);
      final latest = values.last;
      return MetricSummary(
        heroKind: StatHeroKind.latest,
        chartKind: chartKind,
        hero: latest,
        // Latest against the latest of the period before — a change of the
        // person, not of an average of water.
        trend: trendOf(latest, priorPoints.isEmpty ? null : priorPoints.last.value, percent: false),
        sides: [
          StatSide(StatSideKind.lowest, minOf(values), StatValueKind.metric),
          StatSide(StatSideKind.highest, maxOf(values), StatValueKind.metric),
          StatSide(StatSideKind.changeInPeriod, values.last - values.first, StatValueKind.signedMetric),
        ],
      );

    case StatMetric.workoutCount:
      if (values.isEmpty) return empty(StatHeroKind.count);
      final count = sum(values);
      return MetricSummary(
        heroKind: StatHeroKind.count,
        chartKind: chartKind,
        hero: count,
        trend: trendOf(count, sumOrNull(priorPoints)),
        perWeek: perWeek(count),
        sides: [
          StatSide(StatSideKind.mostInAWeek, mostInAWeek(), StatValueKind.count),
          if (current.sampleValues.isNotEmpty) StatSide(StatSideKind.longest, maxOf(current.sampleValues), StatValueKind.duration),
          if (current.sampleValues.isNotEmpty) StatSide(StatSideKind.totalTime, sum(current.sampleValues), StatValueKind.duration),
        ],
      );

    case StatMetric.workoutMinutes:
      if (values.isEmpty) return empty(StatHeroKind.total);
      final total = sum(values);
      return MetricSummary(
        heroKind: StatHeroKind.total,
        chartKind: chartKind,
        hero: total,
        trend: trendOf(total, sumOrNull(priorPoints)),
        sides: [
          if (current.sampleValues.isNotEmpty) StatSide(StatSideKind.avgPerWorkout, mean(current.sampleValues), StatValueKind.duration),
          if (current.sampleValues.isNotEmpty) StatSide(StatSideKind.longest, maxOf(current.sampleValues), StatValueKind.duration),
          if (perWeek(total) != null) StatSide(StatSideKind.perWeek, perWeek(total)!, StatValueKind.duration),
        ],
      );

    case StatMetric.cardioSessions:
      if (values.isEmpty) return empty(StatHeroKind.count);
      final count = sum(values);
      return MetricSummary(
        heroKind: StatHeroKind.count,
        chartKind: chartKind,
        hero: count,
        trend: trendOf(count, sumOrNull(priorPoints)),
        perWeek: perWeek(count),
        sides: [
          if (perWeek(count) != null) StatSide(StatSideKind.perWeek, perWeek(count)!, StatValueKind.count),
          StatSide(StatSideKind.mostInAWeek, mostInAWeek(), StatValueKind.count),
        ],
      );

    case StatMetric.cardioDistance:
    case StatMetric.cardioMovingMinutes:
      if (values.isEmpty) return empty(StatHeroKind.total);
      final total = sum(values);
      final kind = metric == StatMetric.cardioDistance ? StatValueKind.distance : StatValueKind.duration;
      return MetricSummary(
        heroKind: StatHeroKind.total,
        chartKind: chartKind,
        hero: total,
        trend: trendOf(total, sumOrNull(priorPoints)),
        sides: [
          if (current.sampleValues.isNotEmpty) StatSide(StatSideKind.longest, maxOf(current.sampleValues), kind),
          if (current.sampleValues.isNotEmpty) StatSide(StatSideKind.avgPerSession, mean(current.sampleValues), kind),
        ],
      );

    case StatMetric.cardioElevationGain:
      if (values.isEmpty) return empty(StatHeroKind.total);
      final total = sum(values);
      return MetricSummary(
        heroKind: StatHeroKind.total,
        chartKind: chartKind,
        hero: total,
        trend: trendOf(total, sumOrNull(priorPoints)),
        sides: [
          if (current.sampleValues.isNotEmpty) StatSide(StatSideKind.highestSession, maxOf(current.sampleValues), StatValueKind.metric),
        ],
      );

    case StatMetric.cardioHardZoneMinutes:
      if (values.isEmpty) return empty(StatHeroKind.total);
      final total = sum(values);
      return MetricSummary(
        heroKind: StatHeroKind.total,
        chartKind: chartKind,
        hero: total,
        trend: trendOf(total, sumOrNull(priorPoints)),
        sides: [
          if (perWeek(total) != null) StatSide(StatSideKind.perWeek, perWeek(total)!, StatValueKind.duration),
        ],
      );

    case StatMetric.cardioAvgPace:
      if (values.isEmpty) return empty(StatHeroKind.weightedPace);
      double weightedPace(StatSeries s) {
        var minutes = 0.0;
        var km = 0.0;
        for (final p in s.points) {
          final w = s.weights[p.date] ?? 1;
          minutes += p.value * w;
          km += w;
        }
        return km == 0 ? 0 : minutes / km;
      }

      final pace = weightedPace(current);
      return MetricSummary(
        heroKind: StatHeroKind.weightedPace,
        chartKind: chartKind,
        hero: pace,
        trend: prior == null || prior.isEmpty ? null : trendOf(pace, weightedPace(prior)),
        sides: [
          StatSide(StatSideKind.fastest, minOf(values), StatValueKind.pace),
          StatSide(StatSideKind.slowest, maxOf(values), StatValueKind.pace),
        ],
      );

    case StatMetric.maxHeartRate:
      if (values.isEmpty) return empty(StatHeroKind.highest);
      return MetricSummary(
        heroKind: StatHeroKind.highest,
        chartKind: chartKind,
        hero: maxOf(values),
        trend: trendOf(maxOf(values), priorPoints.isEmpty ? null : maxOf([for (final p in priorPoints) p.value]), percent: false),
        sides: [StatSide(StatSideKind.averageOfMaxima, mean(values), StatValueKind.metric)],
      );

    case StatMetric.cardioMaxAltitude:
      if (values.isEmpty) return empty(StatHeroKind.highest);
      return MetricSummary(
        heroKind: StatHeroKind.highest,
        chartKind: chartKind,
        hero: maxOf(values),
        trend: trendOf(maxOf(values), priorPoints.isEmpty ? null : maxOf([for (final p in priorPoints) p.value]), percent: false),
        sides: const [],
      );
  }
}
