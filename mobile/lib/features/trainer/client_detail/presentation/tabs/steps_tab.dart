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

/// The client's last 30 days of steps — chart above, dated history below,
/// mirroring the web's two-column `ClientStepsTab` in the one column a phone
/// has.
class ClientStepsTab extends ConsumerWidget {
  const ClientStepsTab({super.key, required this.clientId, required this.offline});

  final int clientId;
  final bool offline;

  static const _windowDays = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metrics = context.metricColors;
    final locale = Localizations.localeOf(context).toString();
    final integer = NumberFormat.decimalPattern(locale);
    final dateFormat = DateFormat.yMMMd(locale);

    final key = (clientId: clientId, days: _windowDays);
    final steps = ref.watch(clientStepsProvider(key));

    return ClientTabBody(
      states: [steps],
      offline: offline,
      onRefresh: () async {
        ref.invalidate(clientStepsProvider(key));
        await ref.read(clientStepsProvider(key).future);
      },
      builder: (context) {
        final days = steps.requireValue;
        if (days.isEmpty) {
          return EmptyView(
            icon: Icons.directions_walk,
            title: l10n.trainerNoStepsTitle,
            subtitle: l10n.trainerNoStepsMessage,
          );
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const Align(alignment: Alignment.centerRight, child: ReadOnlyBadge()),
            const SizedBox(height: 10),
            TrendChartCard(
              title: l10n.trainerLast30DaysTitle,
              points: [
                for (final day in days) (date: day.date, value: day.steps.toDouble()),
              ],
              accentColor: metrics.steps,
              emptyMessage: l10n.trainerNoStepsTitle,
              valueLabelBuilder: (value) => integer.format(value.round()),
            ),
            const SizedBox(height: 12),
            HistoryCard(
              title: l10n.trainerHistoryTitle,
              rows: [
                for (final day in days.reversed)
                  (
                    label: dateFormat.format(day.date.toLocal()),
                    value: integer.format(day.steps),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
