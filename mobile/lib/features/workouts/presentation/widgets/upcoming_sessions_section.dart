import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../../../shared/widgets/ds/section_label.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import '../../domain/workout_session.dart';

/// A trainer-scheduled session within the client's 7-day visibility window
/// (docs/personal_trainer/08-utemezett-edzesek-koncepcio.md §"Az egyhetes
/// láthatóság"). The 3-month horizon lives entirely server-side — this is a
/// display filter over the same locally-synced [WorkoutSession] rows the
/// history list reads, not a separate sync channel.
bool isWithinUpcomingWindow(WorkoutSession session) {
  if (!session.isUpcoming) return false;
  final day = _dateOnly(session.scheduledFor!.toLocal());
  final today = _dateOnly(DateTime.now());
  final horizon = today.add(const Duration(days: 6));
  return !day.isBefore(today) && !day.isAfter(horizon);
}

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// "Közelgő" section pinned above the history list on the Sessions tab —
/// grouped Today / Tomorrow / weekday name, sorted by day then time (rows
/// with no time last within their day).
class UpcomingSessionsSection extends StatelessWidget {
  const UpcomingSessionsSection({
    super.key,
    required this.sessions,
    required this.onStart,
    required this.onDelete,
  });

  final List<WorkoutSession> sessions;
  final ValueChanged<WorkoutSession> onStart;
  final ValueChanged<WorkoutSession> onDelete;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final sorted = [...sessions]..sort((a, b) {
        final dayCmp = a.scheduledFor!.compareTo(b.scheduledFor!);
        if (dayCmp != 0) return dayCmp;
        final at = a.scheduledTime;
        final bt = b.scheduledTime;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
      });

    final groups = <DateTime, List<WorkoutSession>>{};
    for (final session in sorted) {
      final day = _dateOnly(session.scheduledFor!.toLocal());
      groups.putIfAbsent(day, () => []).add(session);
    }

    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s12, AppSpacing.screen, AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l10n.upcomingSessionsTitle),
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s12, AppSpacing.s4, AppSpacing.s8),
              child: Text(
                _dayLabel(entry.key, l10n),
                style: theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: p.text2),
              ),
            ),
            for (final session in entry.value)
              _UpcomingCard(
                session: session,
                onStart: () => onStart(session),
                onDelete: () => onDelete(session),
              ),
          ],
        ],
      ),
    );
  }

  static String _dayLabel(DateTime day, AppLocalizations l10n) {
    final today = _dateOnly(DateTime.now());
    if (day == today) return l10n.todayGroupLabel;
    if (day == today.add(const Duration(days: 1))) return l10n.tomorrowGroupLabel;
    return DateFormat('EEEE').format(day);
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.session, required this.onStart, required this.onDelete});

  final WorkoutSession session;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: LifeyCard(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s12, AppSpacing.s8, AppSpacing.s12),
        child: Row(
          children: [
            ListIconHolder(icon: Icons.schedule_rounded, color: context.metricColors.weight),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.templateName ?? l10n.freeWorkoutLabel,
                    style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700, height: 1.3, color: p.text),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (session.scheduledTime != null)
                        Text(
                          session.scheduledTime!,
                          style: theme.textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w700, color: p.text2),
                        ),
                      TintedChip(
                        label: l10n.originTrainerBadgeLabel,
                        color: context.metricColors.fat,
                        icon: Icons.school_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.close_rounded, size: 20, color: p.text2),
              tooltip: l10n.deleteWorkoutTooltip,
              visualDensity: VisualDensity.compact,
            ),
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 40),
              ),
              child: Text(l10n.startWorkoutButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
