import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/format/lifey_format.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../../../../shared/widgets/empty_view.dart' show EmptyStateCard;
import '../../../../../shared/widgets/ds/lifey_card.dart';
import '../../application/client_detail_entry.dart';
import '../../application/client_detail_providers.dart';
import '../widgets/client_tab_body.dart';
import '../widgets/history_card.dart';
import '../widgets/nutrition_goals_sheet.dart' show GoalsSaveOutcome;
import '../widgets/read_only_badge.dart';
import '../widgets/step_goal_sheet.dart';
import '../widgets/trend_chart_card.dart';

/// The client's last 30 days of steps — the step goal on top (the trainer's to set, LIF-105), then the chart and the
/// dated history, mirroring the web's two-column `ClientStepsTab` in the one column a phone has.
class ClientStepsTab extends ConsumerWidget {
  const ClientStepsTab({super.key, required this.clientId, required this.offline});

  final int clientId;
  final bool offline;

  static const _windowDays = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metrics = context.metricColors;
    final f = LifeyFormat.of(context);

    final key = (clientId: clientId, days: _windowDays);
    final steps = ref.watch(clientStepsProvider(key));
    // The goal rides in the client summary the screen was built from.
    final stepGoal = ref.watch(trainerClientProvider(clientId)).value?.client.dailyStepGoal;
    final goalCard = _StepGoalCard(clientId: clientId, goal: stepGoal);

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
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, AppSpacing.s24),
            children: [
              goalCard,
              const SizedBox(height: 12),
              EmptyStateCard(
                icon: Icons.directions_walk,
                title: l10n.trainerNoStepsTitle,
                subtitle: l10n.trainerNoStepsMessage,
              ),
            ],
          );
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, AppSpacing.s24),
          children: [
            goalCard,
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerRight, child: ReadOnlyBadge()),
            const SizedBox(height: 10),
            TrendChartCard(
              title: l10n.trainerLast30DaysTitle,
              points: [
                for (final day in days) (date: day.date, value: day.steps.toDouble()),
              ],
              accentColor: metrics.steps,
              emptyMessage: l10n.trainerNoStepsTitle,
              valueLabelBuilder: f.integer,
              axisLabelBuilder: f.compactAxis,
            ),
            const SizedBox(height: 12),
            HistoryCard(
              title: l10n.trainerHistoryTitle,
              rows: [
                for (final day in days.reversed)
                  HistoryRow(
                    label: f.fullDate(day.date.toLocal()),
                    value: f.integer(day.steps),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// "Daily step goal · 10,000 steps · Edit": the one thing on this tab the trainer can change.
class _StepGoalCard extends ConsumerWidget {
  const _StepGoalCard({required this.clientId, required this.goal});

  final int clientId;
  final int? goal;

  Future<void> _edit(BuildContext context, AppLocalizations l10n) async {
    final outcome = await StepGoalSheet.show(context, clientId: clientId, goal: goal);
    if (outcome == null || !context.mounted) return;
    // The "they were told" line only where a push actually went out: the backend notifies on a change.
    AppSnackbar.showSuccess(
      context,
      title: switch (outcome) {
        GoalsSaveOutcome.changed => l10n.trainerStepGoalSavedNotifiedMessage,
        GoalsSaveOutcome.unchanged => l10n.trainerStepGoalSavedMessage,
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final p = context.palette;
    final f = LifeyFormat.of(context);
    final goal = this.goal;

    return LifeyCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.trainerStepGoalTitle, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  goal == null ? l10n.trainerStepGoalNone : l10n.trainerStepGoalValue(f.integer(goal)),
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.text2),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _edit(context, l10n),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text(goal == null ? l10n.trainerSetGoalsAction : l10n.trainerEditGoalsAction),
          ),
        ],
      ),
    );
  }
}
