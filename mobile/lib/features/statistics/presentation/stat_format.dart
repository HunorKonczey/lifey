import 'package:flutter/material.dart';

import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/charts/stats_range.dart';
import '../domain/metric_summary.dart';
import '../domain/stat_metric.dart';

/// How the statistics screen writes a metric's numbers (docs/redesign/77-mobile-
/// redesign-plan.md R4.6): thousands separators everywhere ("255 960"), one
/// decimal only where a decimal means something, durations as "23 h 40" /
/// "72 min", pace as M:SS.
class StatFormat {
  StatFormat(this.context)
      : l10n = AppLocalizations.of(context)!,
        f = LifeyFormat.of(context);

  final BuildContext context;
  final AppLocalizations l10n;
  final LifeyFormat f;

  /// Minutes as "72 min" or "23 h 40".
  String duration(double minutes) {
    final total = minutes.round();
    if (total < 60) return l10n.workoutDurationMin(total);
    return l10n.statDurationHoursMinutes(total ~/ 60, (total % 60).toString().padLeft(2, '0'));
  }

  /// Decimal minutes per kilometre as "5:24".
  String pace(double minutesPerKm) {
    if (!minutesPerKm.isFinite || minutesPerKm <= 0) return '—';
    final seconds = (minutesPerKm * 60).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  /// The number of [metric], without its unit — decimals only for kg, litres
  /// and kilometres.
  String number(StatMetric metric, double value) => switch (metric) {
        StatMetric.weight => f.decimal(value, 1),
        StatMetric.water => f.decimal(value, 1),
        StatMetric.cardioDistance => f.decimal(value, 1),
        StatMetric.cardioAvgPace => pace(value),
        StatMetric.workoutMinutes || StatMetric.cardioMovingMinutes || StatMetric.cardioHardZoneMinutes => duration(value),
        _ => f.integer(value),
      };

  /// The unit that belongs after [number], or null when the number carries it
  /// itself (durations) or has none.
  String? unit(StatMetric metric, {double? value}) => switch (metric) {
        StatMetric.workoutCount => l10n.statUnitWorkouts((value ?? 0).round()),
        StatMetric.cardioSessions => l10n.statUnitSessions((value ?? 0).round()),
        StatMetric.workoutMinutes || StatMetric.cardioMovingMinutes || StatMetric.cardioHardZoneMinutes => null,
        _ => () {
            final u = metric.unitLabel(l10n);
            return u.isEmpty ? null : u;
          }(),
      };

  /// "8 532 steps", "5:24 /km", "23 h 40" — [number] and [unit] joined.
  String withUnit(StatMetric metric, double value) {
    final u = unit(metric, value: value);
    return u == null ? number(metric, value) : '${number(metric, value)} $u';
  }

  String heroOverline(StatMetric metric, StatHeroKind kind, StatsRange range) {
    final label = switch (kind) {
      StatHeroKind.dailyAverage => l10n.statHeroDailyAverage,
      StatHeroKind.latest => l10n.statHeroLatest,
      StatHeroKind.highest => l10n.statHeroHighest,
      StatHeroKind.weightedPace => l10n.statHeroAveragePace,
      StatHeroKind.total || StatHeroKind.count => metric.label(l10n),
    };
    return '$label · ${period(range)}';
  }

  String period(StatsRange range) => switch (range) {
        StatsRange.week => l10n.statPeriodWeek,
        StatsRange.month => l10n.statPeriodMonth,
        StatsRange.quarter => l10n.statPeriodQuarter,
        StatsRange.all => l10n.statPeriodAll,
      };

  String sideLabel(StatSideKind kind) => switch (kind) {
        StatSideKind.lowest => l10n.statSideLowest,
        StatSideKind.highest => l10n.statSideHighest,
        StatSideKind.daysOnTarget => l10n.statSideDaysOnTarget,
        StatSideKind.daysAtGoal => l10n.statSideDaysAtGoal,
        StatSideKind.total => l10n.statSideTotal,
        StatSideKind.changeInPeriod => l10n.statSideChange,
        StatSideKind.perWeek => l10n.statSidePerWeek,
        StatSideKind.mostInAWeek => l10n.statSideMostInWeek,
        StatSideKind.totalTime => l10n.statSideTotalTime,
        StatSideKind.avgPerWorkout => l10n.statSideAvgPerWorkout,
        StatSideKind.avgPerSession => l10n.statSideAvgPerSession,
        StatSideKind.longest => l10n.statSideLongest,
        StatSideKind.highestSession => l10n.statSideHighestSession,
        StatSideKind.fastest => l10n.statSideFastest,
        StatSideKind.slowest => l10n.statSideSlowest,
        StatSideKind.averageOfMaxima => l10n.statSideAvgOfMaxima,
      };

  /// A side stat's value with its unit.
  String sideValue(StatMetric metric, StatSide side) {
    final v = side.value;
    return switch (side.valueKind) {
      StatValueKind.metric => withUnit(metric, v),
      StatValueKind.days => l10n.statDaysValue(v.round()),
      StatValueKind.duration => duration(v),
      StatValueKind.count => f.integer(v),
      StatValueKind.distance => '${f.decimal(v, 1)} ${l10n.statUnitKm}',
      StatValueKind.pace => '${pace(v)} ${l10n.statUnitPaceMinPerKm}',
      StatValueKind.signedMetric => '${f.signedDelta(v)} ${metric.unitLabel(l10n)}',
    };
  }
}

/// Which way a change is good news. Steps, workouts, distance … are better
/// when they go up, a pace when it goes down; calories, weight and heart rate
/// have no fixed direction, so their chips stay in the direction colours.
enum StatTone { higherIsBetter, lowerIsBetter, neutral }

StatTone toneOf(StatMetric metric) => switch (metric) {
      StatMetric.steps ||
      StatMetric.protein ||
      StatMetric.water ||
      StatMetric.workoutCount ||
      StatMetric.workoutMinutes ||
      StatMetric.activeCalories ||
      StatMetric.cardioSessions ||
      StatMetric.cardioDistance ||
      StatMetric.cardioMovingMinutes ||
      StatMetric.cardioElevationGain =>
        StatTone.higherIsBetter,
      StatMetric.cardioAvgPace => StatTone.lowerIsBetter,
      _ => StatTone.neutral,
    };

/// The colour of a trend chip: the improvement green for a change in the good
/// direction, heart red for the wrong one, null (the chip's own direction
/// colour) when there is no good direction.
Color? trendColor(BuildContext context, StatMetric metric, double delta) {
  if (delta == 0) return null;
  final mc = context.metricColors;
  return switch (toneOf(metric)) {
    StatTone.higherIsBetter => delta > 0 ? mc.improvement : mc.heart,
    StatTone.lowerIsBetter => delta < 0 ? mc.improvement : mc.heart,
    StatTone.neutral => null,
  };
}

/// The colour a metric is drawn in — the same accents as the rest of the app.
Color statMetricColor(BuildContext context, StatMetric metric) {
  final mc = context.metricColors;
  return switch (metric) {
    StatMetric.calories => mc.calories,
    StatMetric.protein => mc.protein,
    StatMetric.carbs => mc.carbs,
    StatMetric.fat => mc.fat,
    StatMetric.water => mc.water,
    StatMetric.weight => mc.weight,
    StatMetric.activeCalories => mc.calories,
    StatMetric.workoutMinutes || StatMetric.workoutCount => Theme.of(context).colorScheme.primary,
    StatMetric.steps => mc.steps,
    // The app's "cardio = orange" (`activityTypeColor`).
    StatMetric.cardioDistance ||
    StatMetric.cardioMovingMinutes ||
    StatMetric.cardioElevationGain ||
    StatMetric.cardioAvgPace ||
    StatMetric.cardioSessions ||
    StatMetric.cardioMaxAltitude =>
      mc.calories,
    // Heart-rate metrics take the heart colour (C9.5).
    StatMetric.maxHeartRate || StatMetric.cardioHardZoneMinutes => mc.heart,
  };
}
