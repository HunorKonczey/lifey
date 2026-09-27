import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/format/lifey_format.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/lifey_segmented.dart';
import '../../../../../shared/widgets/ds/metric_tile.dart';
import '../../application/client_detail_providers.dart';
import '../../domain/client_data.dart';
import '../widgets/client_tab_body.dart';
import '../widgets/kpi_grid.dart';
import '../widgets/read_only_badge.dart';
import '../widgets/trend_chart_card.dart';

/// Totals for a chosen window, plus the weight trend behind them — the
/// mobile counterpart of the web's `ClientStatisticsTab`.
class ClientStatisticsTab extends ConsumerStatefulWidget {
  const ClientStatisticsTab({
    super.key,
    required this.clientId,
    required this.offline,
  });

  final int clientId;
  final bool offline;

  @override
  ConsumerState<ClientStatisticsTab> createState() => _ClientStatisticsTabState();
}

class _ClientStatisticsTabState extends ConsumerState<ClientStatisticsTab> {
  ClientStatisticsPeriod _period = ClientStatisticsPeriod.weekly;

  /// A month of totals deserves a year of trend behind it; a week deserves a
  /// quarter. Same pairing as the web tab.
  int get _weightWindowDays =>
      _period == ClientStatisticsPeriod.monthly ? 365 : 90;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final metrics = context.metricColors;
    final f = LifeyFormat.of(context);

    final statsKey = (clientId: widget.clientId, period: _period);
    final weightsKey = (clientId: widget.clientId, days: _weightWindowDays);
    final stats = ref.watch(clientStatisticsProvider(statsKey));
    final weights = ref.watch(clientWeightsProvider(weightsKey));

    String periodLabel(ClientStatisticsPeriod period) => switch (period) {
          ClientStatisticsPeriod.daily => l10n.trainerPeriodDailyLabel,
          ClientStatisticsPeriod.weekly => l10n.trainerPeriodWeeklyLabel,
          ClientStatisticsPeriod.monthly => l10n.trainerPeriodMonthlyLabel,
        };

    return ClientTabBody(
      states: [stats, weights],
      offline: widget.offline,
      onRefresh: () async {
        ref.invalidate(clientStatisticsProvider(statsKey));
        ref.invalidate(clientWeightsProvider(weightsKey));
        await Future.wait([
          ref.read(clientStatisticsProvider(statsKey).future),
          ref.read(clientWeightsProvider(weightsKey).future),
        ]);
      },
      builder: (context) {
        final statistics = stats.requireValue;
        final weightEntries = weights.requireValue;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, AppSpacing.s24),
          children: [
            const Align(alignment: Alignment.centerRight, child: ReadOnlyBadge()),
            const SizedBox(height: AppSpacing.s8),
            LifeySegmented<ClientStatisticsPeriod>(
              segments: [for (final period in ClientStatisticsPeriod.values) (period, periodLabel(period))],
              selected: _period,
              onChanged: (period) => setState(() => _period = period),
            ),
            const SizedBox(height: AppSpacing.s16),
            KpiGrid(
              tiles: [
                MetricTile(
                  icon: Icons.local_fire_department_rounded,
                  label: l10n.caloriesLabel,
                  value: f.kcal(statistics.totalCalories ?? 0),
                  unit: l10n.statUnitKcal,
                  color: metrics.calories,
                ),
                MetricTile(
                  icon: Icons.fitness_center_rounded,
                  label: l10n.workoutsTitle,
                  value: '${statistics.workoutCount ?? 0}',
                  color: theme.colorScheme.primary,
                ),
                MetricTile(
                  icon: Icons.monitor_weight_rounded,
                  label: l10n.weightTitle,
                  value: statistics.latestWeight == null ? '—' : f.weight(statistics.latestWeight!),
                  unit: statistics.latestWeight == null ? null : l10n.statUnitKg,
                  color: metrics.weight,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TrendChartCard(
              title: l10n.trainerWeightTrendTitle,
              points: [
                for (final entry in weightEntries)
                  (date: entry.date, value: entry.weight),
              ],
              accentColor: metrics.weight,
              emptyMessage: l10n.trainerNoWeightEntriesMessage,
              valueLabelBuilder: (value) => l10n.trainerKgValue(f.weight(value)),
              axisLabelBuilder: f.weight,
            ),
          ],
        );
      },
    );
  }
}
