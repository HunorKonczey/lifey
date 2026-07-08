import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(l10n.upcomingSessionsTitle, style: theme.textTheme.titleSmall),
          ),
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
              child: Text(
                _dayLabel(entry.key, l10n),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
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
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 0,
      color: scheme.tertiaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: scheme.tertiary.withValues(alpha: 0.3)),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 20, color: scheme.tertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.templateName ?? l10n.freeWorkoutLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (session.scheduledTime != null) ...[
                        Text(
                          session.scheduledTime!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: AppRadius.pill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.school, size: 11, color: scheme.onTertiaryContainer),
                            const SizedBox(width: 3),
                            Text(
                              l10n.originTrainerBadgeLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: scheme.onTertiaryContainer,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.close, size: 18, color: scheme.onSurfaceVariant),
              tooltip: l10n.deleteWorkoutTooltip,
              visualDensity: VisualDensity.compact,
            ),
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.tertiary,
                foregroundColor: scheme.onTertiary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 36),
              ),
              child: Text(l10n.startWorkoutButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
