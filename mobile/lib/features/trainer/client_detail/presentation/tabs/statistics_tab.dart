import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../application/client_detail_providers.dart';
import '../../domain/client_data.dart';
import '../widgets/client_tab_body.dart';
import '../widgets/metric_card.dart';
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
    final locale = Localizations.localeOf(context).toString();
    final integer = NumberFormat.decimalPattern(locale);

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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final period in ClientStatisticsPeriod.values)
                        ChoiceChip(
                          label: Text(periodLabel(period)),
                          selected: period == _period,
                          showCheckmark: false,
                          selectedColor: theme.colorScheme.tertiaryContainer,
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: period == _period
                                ? theme.colorScheme.onTertiaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          onSelected: (_) => setState(() => _period = period),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const ReadOnlyBadge(),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: l10n.caloriesLabel,
                    value: l10n.trainerKcalValue(
                      integer.format((statistics.totalCalories ?? 0).round()),
                    ),
                    icon: Icons.local_fire_department_outlined,
                    color: metrics.calories,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricCard(
                    label: l10n.workoutsTitle,
                    value: '${statistics.workoutCount ?? 0}',
                    icon: Icons.fitness_center,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricCard(
                    label: l10n.weightTitle,
                    value: statistics.latestWeight == null
                        ? '—'
                        : l10n.trainerKgValue(
                            statistics.latestWeight!.toStringAsFixed(1),
                          ),
                    icon: Icons.monitor_weight_outlined,
                    color: metrics.weight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TrendChartCard(
              title: l10n.trainerWeightTrendTitle,
              points: [
                for (final entry in weightEntries)
                  (date: entry.date, value: entry.weight),
              ],
              accentColor: metrics.weight,
              emptyMessage: l10n.trainerNoWeightEntriesMessage,
              valueLabelBuilder: (value) =>
                  l10n.trainerKgValue(value.toStringAsFixed(1)),
            ),
          ],
        );
      },
    );
  }
}
