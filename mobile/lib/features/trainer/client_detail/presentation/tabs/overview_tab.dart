import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../application/client_detail_providers.dart';
import '../../domain/client_data.dart';
import '../../domain/client_detail_tab.dart';
import '../widgets/client_tab_body.dart';
import '../widgets/metric_card.dart';

/// "What is going on with this client?", answerable in about three seconds
/// (frame C3). Every card is a door: tapping it opens the tab that explains
/// the number.
class ClientOverviewTab extends ConsumerWidget {
  const ClientOverviewTab({
    super.key,
    required this.clientId,
    required this.onOpenTab,
    required this.offline,
  });

  final int clientId;
  final ValueChanged<ClientDetailTab> onOpenTab;
  final bool offline;

  static const _period = ClientStatisticsPeriod.weekly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metrics = context.metricColors;
    final locale = Localizations.localeOf(context).toString();
    final integer = NumberFormat.decimalPattern(locale);

    final statsKey = (clientId: clientId, period: _period);
    final stepsKey = (clientId: clientId, days: _period.days);
    final weightsKey = (clientId: clientId, days: 90);

    final stats = ref.watch(clientStatisticsProvider(statsKey));
    final steps = ref.watch(clientStepsProvider(stepsKey));
    final weights = ref.watch(clientWeightsProvider(weightsKey));

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
      builder: (context) {
        final statistics = stats.requireValue;
        final stepDays = steps.requireValue;
        final weightEntries = weights.requireValue;

        // The weekly totals divided by the period's own length — never a
        // hard-coded 7, so the divisor cannot drift from the window.
        final avgCalories = (statistics.totalCalories ?? 0) / _period.days;
        final avgSteps = stepDays.isEmpty
            ? null
            : stepDays.fold<int>(0, (sum, day) => sum + day.steps) / stepDays.length;
        final latest = weightEntries.isNotEmpty ? weightEntries.last : null;
        final previous =
            weightEntries.length > 1 ? weightEntries[weightEntries.length - 2] : null;
        final weightDelta = latest != null && previous != null
            ? latest.weight - previous.weight
            : null;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: [
                MetricCard(
                  label: l10n.trainerMetricAvgCaloriesLabel,
                  value: l10n.trainerKcalValue(integer.format(avgCalories.round())),
                  icon: Icons.local_fire_department_outlined,
                  color: metrics.calories,
                  onTap: () => onOpenTab(ClientDetailTab.nutrition),
                ),
                MetricCard(
                  label: l10n.trainerMetricCurrentWeightLabel,
                  value: latest == null
                      ? '—'
                      : l10n.trainerKgValue(latest.weight.toStringAsFixed(1)),
                  icon: Icons.monitor_weight_outlined,
                  color: metrics.weight,
                  delta: weightDelta,
                  // The sign is built here rather than in the ARB: "+0.3"
                  // and "-0.3" are one string with a leading character, not
                  // two phrasings a translator has to choose between.
                  deltaLabel: weightDelta == null
                      ? null
                      : l10n.trainerKgDeltaValue(
                          '${weightDelta > 0 ? '+' : ''}'
                          '${weightDelta.toStringAsFixed(1)}',
                        ),
                  lowerIsBetter: true,
                  onTap: () => onOpenTab(ClientDetailTab.weight),
                ),
                MetricCard(
                  label: l10n.trainerMetricWorkoutsThisWeekLabel,
                  value: '${statistics.workoutCount ?? 0}',
                  icon: Icons.fitness_center,
                  color: Theme.of(context).colorScheme.tertiary,
                  onTap: () => onOpenTab(ClientDetailTab.statistics),
                ),
                MetricCard(
                  label: l10n.trainerMetricAvgStepsLabel,
                  value: avgSteps == null ? '—' : integer.format(avgSteps.round()),
                  icon: Icons.directions_walk,
                  color: metrics.steps,
                  onTap: () => onOpenTab(ClientDetailTab.steps),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.trainerOverviewPeriodHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );
      },
    );
  }
}
