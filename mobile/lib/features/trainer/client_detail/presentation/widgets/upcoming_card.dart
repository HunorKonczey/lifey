import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/format/lifey_format.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../../shared/widgets/ds/list_group.dart';
import '../../../schedule/application/client_schedules_controller.dart';
import '../../../schedule/application/recurrence_text.dart';
import '../../../schedule/domain/schedule.dart';

/// The client's next sessions, beside the weight trend on the tablet's overview
/// (canvas Lifey 6 › Trainer tablet): a title and up to four rows — a 40 dp
/// icon holder, the workout's name, the day and time under it — divided by
/// hairlines. Tapping the card opens the schedule tab, where they can be
/// changed.
class UpcomingCard extends ConsumerWidget {
  const UpcomingCard({super.key, required this.clientId, required this.onTap});

  final int clientId;
  final VoidCallback onTap;

  /// More than this and the card is a schedule of its own, which the tab is for.
  static const maxRows = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final f = LifeyFormat.of(context);
    final upcoming = ref.watch(clientUpcomingOccurrencesProvider(clientId));

    Widget body(List<CalendarSession> sessions) {
      if (sessions.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
          child: Text(l10n.trainerNoSchedulesTitle, style: t.bodyMedium?.copyWith(color: p.text2)),
        );
      }
      return Column(
        children: [
          for (final (i, session) in sessions.take(maxRows).indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: p.hairline),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  ListIconHolder(icon: Icons.event_rounded, color: Theme.of(context).colorScheme.primary, size: 40),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.templateName ?? l10n.trainerFreeWorkoutLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleSmall,
                        ),
                        Text(
                          [
                            f.shortDayLabel(session.scheduledFor.toLocal()),
                            if (session.scheduledTime != null) formatScheduleTime(session.scheduledTime!),
                          ].join(' · '),
                          style: t.bodySmall?.copyWith(color: p.text2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return LifeyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: Text(l10n.trainerUpcomingCardTitle, style: t.titleMedium),
          ),
          upcoming.when(
            data: body,
            // The card is a glance; a failure here is the schedule tab's to
            // explain, not a second error on the overview.
            error: (_, __) => body(const []),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
              child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          ),
        ],
      ),
    );
  }
}
