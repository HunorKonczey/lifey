import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/format/lifey_format.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/metric_tile.dart';
import '../../../../../shared/widgets/ds/tinted_chip.dart';
import '../../application/client_detail_providers.dart';
import '../../application/client_sessions_controller.dart';
import '../../domain/client_data.dart';
import '../../domain/client_detail_tab.dart';
import '../../domain/client_workout_session.dart';
import '../widgets/client_tab_body.dart';
import '../widgets/kpi_grid.dart';
import '../widgets/trend_chart_card.dart';

/// "What is going on with this client?", answerable in about three seconds
/// (canvas Lifey 6, client overview): four KPI tiles for the last 7 days, each
/// with a line that puts the number in context, and the weight trend under
/// them. Every tile and the chart are doors: tapping one opens the tab that
/// explains the number.
class ClientOverviewTab extends ConsumerWidget {
  const ClientOverviewTab({
    super.key,
    required this.clientId,
    required this.onOpenTab,
    required this.offline,
    this.missedWorkoutCount = 0,
  });

  final int clientId;
  final ValueChanged<ClientDetailTab> onOpenTab;
  final bool offline;

  /// Planned sessions the client skipped in the last 14 days, from the client
  /// list's summary — the one place that is counted.
  final int missedWorkoutCount;

  static const _period = ClientStatisticsPeriod.weekly;

  /// The weight trend card's window, in days (the chip says so).
  static const weightWindowDays = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsKey = (clientId: clientId, period: _period);
    final stepsKey = (clientId: clientId, days: _period.days);
    final weightsKey = (clientId: clientId, days: 90);

    final stats = ref.watch(clientStatisticsProvider(statsKey));
    final steps = ref.watch(clientStepsProvider(stepsKey));
    final weights = ref.watch(clientWeightsProvider(weightsKey));
    // Two extras that sharpen the tiles but are not worth blocking (or
    // failing) the overview for: the calorie goal and the sessions the RPE is
    // averaged from. Both are shared with the tabs that own them.
    final goals = ref.watch(clientNutritionGoalsProvider(clientId)).value;
    final sessions = ref.watch(clientSessionsControllerProvider(clientId));

    return ClientTabBody(
      states: [stats, steps, weights],
      offline: offline,
      onRefresh: () async {
        ref.invalidate(clientStatisticsProvider(statsKey));
        ref.invalidate(clientStepsProvider(stepsKey));
        ref.invalidate(clientWeightsProvider(weightsKey));
        await Future.wait([
          ref.read(clientStatisticsProvider(statsKey).future),
          ref.read(clientStepsProvider(stepsKey).future),
          ref.read(clientWeightsProvider(weightsKey).future),
        ]);
      },
      builder: (context) => _Content(
        statistics: stats.requireValue,
        stepDays: steps.requireValue,
        weights: weights.requireValue,
        calorieGoal: goals?.dailyCalorieGoal,
        recentSessions: sessions.sessions,
        missedWorkoutCount: missedWorkoutCount,
        onOpenTab: onOpenTab,
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.statistics,
    required this.stepDays,
    required this.weights,
    required this.calorieGoal,
    required this.recentSessions,
    required this.missedWorkoutCount,
    required this.onOpenTab,
  });

  final ClientStatistics statistics;
  final List<ClientStepDay> stepDays;
  final List<ClientWeightEntry> weights;
  final double? calorieGoal;
  final List<ClientWorkoutSession> recentSessions;
  final int missedWorkoutCount;
  final ValueChanged<ClientDetailTab> onOpenTab;

  /// Mean of the RPEs the client gave in the last 7 days, or null when they
  /// rated nothing — a missing rating is not a zero.
  double? _averageRpe(DateTime now) {
    final since = now.subtract(const Duration(days: 7));
    final rated = [
      for (final s in recentSessions)
        if (s.rpe != null && s.startedAt.isAfter(since)) s.rpe!,
    ];
    if (rated.isEmpty) return null;
    return rated.reduce((a, b) => a + b) / rated.length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final mc = context.metricColors;

    // The weekly totals divided by the period's own length — never a
    // hard-coded 7, so the divisor cannot drift from the window.
    final avgCalories = (statistics.totalCalories ?? 0) / ClientOverviewTab._period.days;
    final goal = calorieGoal;
    final avgSteps = stepDays.isEmpty ? null : stepDays.fold<int>(0, (sum, day) => sum + day.steps) / stepDays.length;
    final avgRpe = _averageRpe(DateTime.now());
    final workouts = statistics.workoutCount ?? 0;

    // Weight: the readings of the last 30 days before the latest one; a change
    // needs two of them.
    final latest = weights.isNotEmpty ? weights.last : null;
    final windowStart = latest?.date.subtract(const Duration(days: ClientOverviewTab.weightWindowDays));
    final windowed = [
      for (final w in weights)
        if (windowStart != null && !w.date.isBefore(windowStart)) w,
    ];
    final weightChange = windowed.length > 1 ? windowed.last.weight - windowed.first.weight : null;

    final tiles = [
      MetricTile(
        icon: Icons.local_fire_department_rounded,
        label: l10n.trainerKpiAvgCalories,
        value: f.kcal(avgCalories),
        unit: l10n.statUnitKcal,
        color: mc.calories,
        subline: goal != null && goal > 0 ? l10n.trainerKpiCalorieGoal(f.percent(avgCalories / goal)) : null,
        onTap: () => onOpenTab(ClientDetailTab.nutrition),
      ),
      MetricTile(
        icon: Icons.fitness_center_rounded,
        label: l10n.trainerKpiWorkouts,
        value: '$workouts',
        color: Theme.of(context).colorScheme.primary,
        subline: missedWorkoutCount > 0 ? l10n.trainerKpiWorkoutsMissed(missedWorkoutCount) : null,
        onTap: () => onOpenTab(ClientDetailTab.statistics),
      ),
      MetricTile(
        icon: Icons.directions_walk_rounded,
        label: l10n.trainerKpiAvgSteps,
        value: avgSteps == null ? '—' : f.integer(avgSteps),
        color: mc.steps,
        subline: stepDays.isEmpty ? null : l10n.trainerKpiStepsDays(stepDays.length),
        onTap: () => onOpenTab(ClientDetailTab.steps),
      ),
      MetricTile(
        icon: Icons.favorite_rounded,
        label: l10n.trainerKpiAvgRpe,
        value: avgRpe == null ? '—' : f.decimal(avgRpe, 1),
        unit: avgRpe == null ? null : l10n.trainerKpiRpeScale,
        color: mc.heart,
        subline: avgRpe == null ? null : _rpeWords(l10n, avgRpe),
        onTap: () => onOpenTab(ClientDetailTab.workouts),
      ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s16, AppSpacing.screen, AppSpacing.s24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Text(
            l10n.trainerOverviewLast7DaysLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: p.text2),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        KpiGrid(tiles: tiles),
        const SizedBox(height: 10),
        TrendChartCard(
          title: l10n.trainerWeightTrendTitle,
          subtitle: latest == null
              ? null
              : l10n.trainerWeightLatestLabel(f.weight(latest.weight), f.shortDate(latest.date.toLocal())),
          trailing: weightChange == null
              ? null
              : TintedChip(
                  label: l10n.trainerWeightChangeChip(f.signedDelta(weightChange), ClientOverviewTab.weightWindowDays),
                  color: mc.weight,
                ),
          points: [for (final w in windowed) (date: w.date, value: w.weight)],
          accentColor: mc.weight,
          emptyMessage: l10n.trainerNoWeightEntriesMessage,
          valueLabelBuilder: (value) => l10n.trainerKgValue(f.weight(value)),
          chartHeight: 140,
          onTap: () => onOpenTab(ClientDetailTab.weight),
        ),
      ],
    );
  }

  /// The RPE scale in words, so "7.2" reads as an effort rather than a score.
  static String _rpeWords(AppLocalizations l10n, double rpe) {
    if (rpe < 4) return l10n.trainerKpiRpeLight;
    if (rpe < 6) return l10n.trainerKpiRpeModerate;
    if (rpe < 8) return l10n.trainerKpiRpeHard;
    if (rpe < 9.5) return l10n.trainerKpiRpeVeryHard;
    return l10n.trainerKpiRpeMaximal;
  }
}
