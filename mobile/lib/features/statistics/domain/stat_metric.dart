import '../../../l10n/app_localizations.dart';

/// How a day's values for a [StatMetric] should be reduced to one point.
enum StatAggregationType {
  /// Add up every value recorded that day (e.g. total calories eaten).
  sum,

  /// Average every value recorded that day (e.g. average heart rate).
  average,

  /// Σ numerator / Σ denominator across the day's values, not the arithmetic
  /// mean of each value's own ratio (docs/cardio/56-cardio-statistics-plan.md
  /// D-C3.6) — e.g. pace: Σ moving time / Σ distance, so a 1 km jog and a
  /// 20 km run on the same day don't count equally toward the day's pace.
  weightedAverage,

  /// Keep only the most recently recorded value that day (e.g. weight).
  lastOfDay,
}

/// A statistic chartable on the statistics screen, with its display label,
/// unit, and how daily values should be aggregated. Values are computed
/// elsewhere (application layer) from the already-migrated feature
/// repositories (meals, sessions, water, weight) — this enum only carries
/// the metadata needed to label and aggregate them.
enum StatMetric {
  calories,
  protein,
  carbs,
  fat,
  workoutMinutes,
  workoutCount,
  activeCalories,
  water,
  weight,
  steps,

  // Cardio fajta-bontás (docs/cardio/56-cardio-statistics-plan.md §3, C3.2)
  // — deliberately not exposed as `strengthWorkoutCount`/`cardioWorkoutCount`
  // duplicates of [workoutCount] (D-C3.4): the statistics screen's kind
  // filter narrows the existing metrics instead, these six are the metrics
  // that only exist *for* cardio in the first place.
  cardioDistance,
  cardioMovingMinutes,
  cardioElevationGain,
  cardioAvgPace,
  maxHeartRate,
  cardioSessions,

  /// Time spent at threshold or above — zones 4+5 (docs/cardio/60 C9.5).
  ///
  /// **Not** total zone time: the five zones together add up to roughly the
  /// session itself, which [cardioMovingMinutes] already charts. The training
  /// question a zone chart answers is "how much hard work did I do this
  /// week", and that is Z4+Z5.
  cardioHardZoneMinutes;

  String label(AppLocalizations l10n) => switch (this) {
        StatMetric.calories => l10n.caloriesLabel,
        StatMetric.protein => l10n.proteinLabel,
        StatMetric.carbs => l10n.carbsLabel,
        StatMetric.fat => l10n.fatLabel,
        StatMetric.workoutMinutes => l10n.statMetricWorkoutMinutesLabel,
        StatMetric.workoutCount => l10n.statMetricWorkoutCountLabel,
        StatMetric.activeCalories => l10n.statMetricActiveCaloriesLabel,
        StatMetric.water => l10n.waterLabel,
        StatMetric.weight => l10n.weightTitle,
        StatMetric.steps => l10n.stepsLabel,
        StatMetric.cardioDistance => l10n.statMetricCardioDistanceLabel,
        StatMetric.cardioMovingMinutes => l10n.statMetricCardioMovingMinutesLabel,
        StatMetric.cardioElevationGain => l10n.statMetricCardioElevationGainLabel,
        StatMetric.cardioAvgPace => l10n.statMetricCardioAvgPaceLabel,
        StatMetric.maxHeartRate => l10n.statMetricMaxHeartRateLabel,
        StatMetric.cardioSessions => l10n.statMetricCardioSessionsLabel,
        StatMetric.cardioHardZoneMinutes => l10n.statMetricCardioHardZoneMinutesLabel,
      };

  /// Unit shown next to the value (e.g. "kcal", "g"). Empty for the
  /// dimensionless [workoutCount]/[cardioSessions].
  ///
  /// Always metric (km, m), matching [weight]/[water] on this screen already
  /// ignoring `UnitSystem` — the statistics screen has never been
  /// unit-system-aware, and giving these two new metrics that awareness
  /// alone (while weight/water still aren't) would be a bigger, inconsistent
  /// change than C3.2 asks for.
  String unitLabel(AppLocalizations l10n) => switch (this) {
        StatMetric.calories => l10n.statUnitKcal,
        StatMetric.protein => l10n.statUnitGrams,
        StatMetric.carbs => l10n.statUnitGrams,
        StatMetric.fat => l10n.statUnitGrams,
        StatMetric.workoutMinutes => l10n.statUnitMinutes,
        StatMetric.workoutCount => '',
        StatMetric.activeCalories => l10n.statUnitKcal,
        StatMetric.water => l10n.statUnitLiters,
        StatMetric.weight => l10n.statUnitKg,
        StatMetric.steps => l10n.statUnitSteps,
        StatMetric.cardioDistance => l10n.statUnitKm,
        StatMetric.cardioMovingMinutes => l10n.statUnitMinutes,
        StatMetric.cardioElevationGain => l10n.statUnitMeters,
        StatMetric.cardioAvgPace => l10n.statUnitPaceMinPerKm,
        StatMetric.maxHeartRate => l10n.statUnitBpm,
        StatMetric.cardioSessions => '',
        StatMetric.cardioHardZoneMinutes => l10n.statUnitMinutes,
      };

  /// How daily values for this metric should be combined into one point.
  StatAggregationType get aggregation => switch (this) {
        StatMetric.calories => StatAggregationType.sum,
        StatMetric.protein => StatAggregationType.sum,
        StatMetric.carbs => StatAggregationType.sum,
        StatMetric.fat => StatAggregationType.sum,
        StatMetric.workoutMinutes => StatAggregationType.sum,
        StatMetric.workoutCount => StatAggregationType.sum,
        StatMetric.activeCalories => StatAggregationType.sum,
        StatMetric.water => StatAggregationType.sum,
        StatMetric.weight => StatAggregationType.lastOfDay,
        StatMetric.steps => StatAggregationType.sum,
        StatMetric.cardioDistance => StatAggregationType.sum,
        StatMetric.cardioMovingMinutes => StatAggregationType.sum,
        StatMetric.cardioElevationGain => StatAggregationType.sum,
        StatMetric.cardioAvgPace => StatAggregationType.weightedAverage,
        // Each day's point is already that day's max (see
        // `_maxHeartRatePoints`, stat_chart_data.dart) — `average` here
        // describes what the summary card then does across days ("average
        // of daily maximums", 56 §3), not a within-day average.
        StatMetric.maxHeartRate => StatAggregationType.average,
        StatMetric.cardioSessions => StatAggregationType.sum,
        StatMetric.cardioHardZoneMinutes => StatAggregationType.sum,
      };
}
