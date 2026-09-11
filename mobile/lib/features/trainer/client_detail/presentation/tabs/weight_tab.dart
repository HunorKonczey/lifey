import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/empty_view.dart';
import '../../application/client_detail_providers.dart';
import '../widgets/client_tab_body.dart';
import '../widgets/history_card.dart';
import '../widgets/read_only_badge.dart';
import '../widgets/trend_chart_card.dart';

/// The client's weigh-ins over the last quarter.
///
/// The web folds weight into its statistics tab; on a phone that tab would
/// have to carry a period switch, three metrics and two charts at once, so
/// the plan gives weight its own tab (T2 tab list, frame C1). Same data,
/// same chart, more room.
class ClientWeightTab extends ConsumerWidget {
  const ClientWeightTab({super.key, required this.clientId, required this.offline});

  final int clientId;
  final bool offline;

  static const _windowDays = 90;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metrics = context.metricColors;
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMMMd(locale);

    final key = (clientId: clientId, days: _windowDays);
    final weights = ref.watch(clientWeightsProvider(key));

    return ClientTabBody(
      states: [weights],
      offline: offline,
      onRefresh: () async {
        ref.invalidate(clientWeightsProvider(key));
        await ref.read(clientWeightsProvider(key).future);
      },
      builder: (context) {
        final entries = weights.requireValue;
        if (entries.isEmpty) {
          return EmptyView(
            icon: Icons.monitor_weight_outlined,
            title: l10n.trainerNoWeightEntriesMessage,
            subtitle: l10n.trainerNoWeightEntriesHint,
          );
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const Align(alignment: Alignment.centerRight, child: ReadOnlyBadge()),
            const SizedBox(height: 10),
            TrendChartCard(
              title: l10n.trainerLast90DaysTitle,
              points: [
                for (final entry in entries) (date: entry.date, value: entry.weight),
              ],
              accentColor: metrics.weight,
              emptyMessage: l10n.trainerNoWeightEntriesMessage,
              valueLabelBuilder: (value) =>
                  l10n.trainerKgValue(value.toStringAsFixed(1)),
            ),
            const SizedBox(height: 12),
            HistoryCard(
              title: l10n.trainerHistoryTitle,
              rows: [
                for (final entry in entries.reversed)
                  (
                    label: dateFormat.format(entry.date.toLocal()),
                    value: l10n.trainerKgValue(entry.weight.toStringAsFixed(1)),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
