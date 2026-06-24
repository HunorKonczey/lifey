import '../../../l10n/app_localizations.dart';

/// How a day's values for a [StatMetric] should be reduced to one point.
enum StatAggregationType {
  /// Add up every value recorded that day (e.g. total calories eaten).
  sum,

  /// Average every value recorded that day (e.g. average heart rate).
  average,

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
  steps;

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
      };

  /// Unit shown next to the value (e.g. "kcal", "g"). Empty for the
  /// dimensionless [workoutCount].
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
      };
}
