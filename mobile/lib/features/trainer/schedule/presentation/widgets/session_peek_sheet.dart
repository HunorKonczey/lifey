import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/network/error_message.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../../../shared/widgets/trainer_view_menu.dart';
import '../../../clients/domain/trainer_client.dart';
import '../../../shared/client_avatar.dart';
import '../../application/client_schedules_controller.dart';
import '../../application/recurrence_text.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule.dart';
import 'occurrence_status_chip.dart';

/// One occurrence, tapped (frame F3).
///
/// A bottom sheet rather than a popover: on a touch surface the sheet is the
/// native pattern, and the peek carries enough — who, what, when, how it
/// repeats — that a hover card would be too small for it anyway.
class SessionPeekSheet extends ConsumerStatefulWidget {
  const SessionPeekSheet({
    super.key,
    required this.session,
    required this.client,
    this.scheduleRule,
  });

  final CalendarSession session;

  /// Null when the occurrence belongs to a client who has since left the
  /// roster — the row is still on the calendar, so it still opens.
  final TrainerClient? client;

  /// The series this occurrence came from, when the caller already has it —
  /// the client's own schedule tab does. The calendar does not: its endpoint
  /// returns a `scheduleId` and no rule, so the sheet looks the rule up by
  /// client instead (see [_resolvedRule]).
  final ScheduleSummary? scheduleRule;

  /// Returns true when the occurrence was cancelled, so the caller can
  /// refresh.
  static Future<bool?> show(
    BuildContext context, {
    required CalendarSession session,
    required TrainerClient? client,
    ScheduleSummary? scheduleRule,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (_) => SessionPeekSheet(
        session: session,
        client: client,
        scheduleRule: scheduleRule,
      ),
    );
  }

  @override
  ConsumerState<SessionPeekSheet> createState() => _SessionPeekSheetState();
}

class _SessionPeekSheetState extends ConsumerState<SessionPeekSheet> {
  bool _cancelling = false;

  Future<void> _cancel(AppLocalizations l10n) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: l10n.trainerCancelOccurrenceConfirmTitle,
      message: l10n.trainerCancelOccurrenceConfirmMessage,
    );
    if (!confirmed || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .cancelOccurrence(widget.session.sessionId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _cancelling = false);
        AppSnackbar.showError(context, title: friendlyError(error));
      }
    }
  }

  /// The rule behind this occurrence, from the caller or looked up.
  ///
  /// The lookup asks for the client's schedules — one request, cached per
  /// client, so peeking at a second session of the same person costs
  /// nothing. Null while it is in flight or if the series is gone, and the
  /// recurrence line simply does not appear rather than showing a guess.
  ScheduleSummary? _resolvedRule() {
    if (widget.scheduleRule != null) return widget.scheduleRule;
    final scheduleId = widget.session.scheduleId;
    if (scheduleId == null || widget.session.clientId == 0) return null;

    final schedules =
        ref.watch(clientSchedulesProvider(widget.session.clientId)).value;
    if (schedules == null) return null;
    for (final schedule in schedules) {
      if (schedule.id == scheduleId) return schedule;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final session = widget.session;
    final client = widget.client;
    final rule = _resolvedRule();

    final when = [
      DateFormat.yMMMEd(locale).format(session.scheduledFor.toLocal()),
      if (session.scheduledTime != null) formatScheduleTime(session.scheduledTime!),
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (client != null) ...[
                ClientAvatar(client: client, size: 40),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client?.displayName ??
                          session.clientEmail ??
                          l10n.trainerUnknownClientLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      session.templateName ?? l10n.trainerFreeWorkoutLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              OccurrenceStatusChip(status: session.status),
            ],
          ),
          const SizedBox(height: 14),
          _Line(icon: Icons.event, text: when),
          if (rule != null)
            _Line(
              icon: Icons.repeat,
              text: recurrenceSummary(
                l10n,
                locale,
                recurrence: rule.recurrence,
                daysOfWeek: rule.daysOfWeek,
                startDate: rule.startDate,
                endDate: rule.endDate,
                timeOfDay: rule.timeOfDay,
              ),
            ),
          if (session.isFromProgram)
            _Line(
              icon: Icons.calendar_view_week,
              text: session.programName ?? l10n.trainerFromProgramLabel,
            ),
          const SizedBox(height: 16),
          if (client != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('$trainerShellLocation/${client.userId}');
                },
                icon: const Icon(Icons.person_outline, size: 18),
                label: Text(l10n.trainerOpenClientAction),
              ),
            ),
          // Offered only where the backend will accept it: anything already
          // started, past or called off answers 409.
          if (session.isCancellable)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _cancelling ? null : () => _cancel(l10n),
                icon: _cancelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.event_busy, size: 18),
                label: Text(l10n.trainerCancelOccurrenceAction),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
