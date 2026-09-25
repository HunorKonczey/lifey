import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/delta_chip.dart';
import '../../../../shared/widgets/ds/metric_tile.dart';
import '../../../../shared/widgets/ds/sparkline.dart';
import '../../../settings/domain/user_settings.dart';
import '../../../weight/domain/weight_entry.dart';
import '../../domain/daily_stats.dart';

/// The change between the two most recent weigh-ins, signed: negative = lost.
/// Null when there are fewer than two entries, or the weight didn't change.
/// [entries] are newest first.
double? latestWeightChange(List<WeightEntry> entries) {
  if (entries.length < 2) return null;
  final diff = entries[0].weight - entries[1].weight;
  return diff == 0 ? null : diff;
}

/// Water and steps side by side, weight full width under them — the three
/// metric tiles of the Today screen (docs/redesign/77-mobile-redesign-plan.md
/// R1.4; canvas Lifey 1).
///
/// - **Water:** "0.99 / 2.6 L", a 7 px bar and a 48 dp `+` that opens the add
///   sheet. Without a goal: just "0.99 L", no bar.
/// - **Steps:** "6 412 of 10 000" against [UserSettings.effectiveDailyStepGoal]
///   (the 10 000 default when none is set). Only when there is step data —
///   without it (no health integration) the water tile takes the full width.
/// - **Weight:** "64.5 kg" with a delta chip against the previous entry (blue
///   for a loss, calorie orange for a gain — never green: whether a change is
///   good depends on the user's goal, which the tile doesn't know), the
///   "Latest entry · today" line on its own row so the Hungarian one is never
///   truncated, and a 10-entry sparkline.
class DashboardTiles extends StatelessWidget {
  const DashboardTiles({
    super.key,
    required this.stats,
    required this.settings,
    required this.weights,
    required this.onAddWater,
    required this.onWeightTap,
    this.todaySteps,
    this.now,
  });

  final DailyStats stats;
  final UserSettings settings;

  /// Today's steps; null = no step data on this device.
  final int? todaySteps;

  /// Weigh-ins, newest first.
  final List<WeightEntry> weights;

  final VoidCallback onAddWater;
  final VoidCallback onWeightTap;

  /// The clock, for "today" / "yesterday" — injectable for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final mc = context.metricColors;

    final waterGoal = settings.dailyWaterGoalLiters;
    final hasWaterGoal = waterGoal != null && waterGoal > 0;
    final waterTile = MetricTile(
      icon: Icons.water_drop_rounded,
      label: l10n.waterLabel,
      value: f.litres(stats.water),
      unit: hasWaterGoal ? l10n.dashboardWaterOfGoal(f.litres(waterGoal)) : 'L',
      color: mc.water,
      progress: hasWaterGoal ? stats.water / waterGoal : null,
      onAction: onAddWater,
      actionTooltip: l10n.logWaterTitle,
    );

    final steps = todaySteps;
    final stepGoal = settings.effectiveDailyStepGoal;
    final stepsTile = steps == null
        ? null
        : MetricTile(
            icon: Icons.directions_walk_rounded,
            label: l10n.dashboardStepsTileLabel,
            value: f.integer(steps),
            unit: l10n.dashboardStepsOfGoal(f.integer(stepGoal)),
            color: mc.steps,
            progress: steps / stepGoal,
          );

    final latestWeight = stats.latestWeight;
    final change = latestWeightChange(weights);
    final weightTile = MetricTile(
      icon: Icons.monitor_weight_rounded,
      label: l10n.weightLabel,
      value: latestWeight == null ? '—' : f.weight(latestWeight),
      unit: latestWeight == null ? null : 'kg',
      color: mc.weight,
      delta: change == null ? null : DeltaChip.arrow(value: change, unit: 'kg'),
      subline: weights.isEmpty
          ? null
          : l10n.dashboardWeightLatestEntry(_relativeDay(l10n, f, weights.first.date)),
      trailing: weights.length < 2
          ? null
          : Sparkline(
              values: [for (final w in weights.take(10).toList().reversed) w.weight],
              color: mc.weight,
            ),
      onTap: onWeightTap,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: waterTile),
              if (stepsTile != null) ...[
                const SizedBox(width: AppSpacing.s12),
                Expanded(child: stepsTile),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        weightTile,
      ],
    );
  }

  /// "today" / "yesterday" / "Sep 22" — the day a weight was logged for.
  String _relativeDay(AppLocalizations l10n, LifeyFormat f, DateTime date) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return l10n.dashboardDayToday;
    if (diff == 1) return l10n.dashboardDayYesterday;
    return f.shortDate(day);
  }
}
