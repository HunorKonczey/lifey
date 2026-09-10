import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/network/error_message.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../../../shared/widgets/empty_view.dart';
import '../../../programs/application/programs_controller.dart';
import '../../../programs/domain/program.dart';
import '../../../programs/domain/program_dates.dart';
import '../../../schedule/application/client_schedules_controller.dart';
import '../../../schedule/application/recurrence_text.dart';
import '../../../schedule/domain/schedule.dart';
import '../../../schedule/presentation/widgets/create_schedule_sheet.dart';
import '../../../schedule/presentation/widgets/occurrence_status_chip.dart';
import '../../../schedule/presentation/widgets/session_peek_sheet.dart';
import '../widgets/client_tab_body.dart';

/// One client's schedules and what is coming up for them
/// (docs/chat/41-trainer-mobile-v2-plan.md T5).
///
/// The tab carries both delete paths, because they are different decisions:
/// calling off a *series* stops every future occurrence of it, while calling
/// off one occurrence leaves the series running. The web splits them the same
/// way, and the confirmation says which is which.
class ClientScheduleTab extends ConsumerWidget {
  const ClientScheduleTab({
    super.key,
    required this.clientId,
    required this.offline,
  });

  final int clientId;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final schedules = ref.watch(clientSchedulesProvider(clientId));
    final upcoming = ref.watch(clientUpcomingOccurrencesProvider(clientId));
    final programs = ref.watch(clientProgramAssignmentsProvider(clientId));

    Future<void> refresh() async {
      ref.invalidate(clientSchedulesProvider(clientId));
      ref.invalidate(clientUpcomingOccurrencesProvider(clientId));
      ref.invalidate(clientProgramAssignmentsProvider(clientId));
      await Future.wait([
        ref.read(clientSchedulesProvider(clientId).future),
        ref.read(clientUpcomingOccurrencesProvider(clientId).future),
        ref.read(clientProgramAssignmentsProvider(clientId).future),
      ]);
    }

    return Stack(
      children: [
        ClientTabBody(
          states: [schedules, upcoming, programs],
          offline: offline,
          onRefresh: refresh,
          builder: (context) {
            final series = schedules.requireValue;
            final occurrences = upcoming.requireValue;
            final runs = programs.requireValue;

            if (series.isEmpty && occurrences.isEmpty && runs.isEmpty) {
              return EmptyView(
                icon: Icons.event_outlined,
                title: l10n.trainerNoSchedulesTitle,
                subtitle: l10n.trainerNoSchedulesMessage,
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                // Program runs first: they are the bigger commitment, and
                // the loose schedules below them are usually the extras
                // hung around one.
                if (runs.isNotEmpty) ...[
                  _SectionHeader(title: l10n.trainerProgramsSectionTitle),
                  for (final run in runs)
                    _ProgramRunCard(run: run, onCancelled: refresh),
                  const SizedBox(height: 12),
                ],
                if (series.isNotEmpty) ...[
                  _SectionHeader(title: l10n.trainerSchedulesSectionTitle),
                  for (final schedule in series)
                    _ScheduleCard(
                      schedule: schedule,
                      onCancelled: refresh,
                    ),
                  const SizedBox(height: 12),
                ],
                if (occurrences.isNotEmpty) ...[
                  _SectionHeader(title: l10n.trainerUpcomingSectionTitle),
                  for (final occurrence in occurrences)
                    _OccurrenceRow(
                      occurrence: occurrence,
                      schedule: _seriesOf(series, occurrence),
                      onChanged: refresh,
                    ),
                ],
              ],
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: null,
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            foregroundColor: Theme.of(context).colorScheme.onTertiary,
            icon: const Icon(Icons.add),
            label: Text(l10n.trainerScheduleWorkoutAction),
            onPressed: () async {
              final created =
                  await CreateScheduleSheet.show(context, clientId: clientId);
              if (created ?? false) await refresh();
            },
          ),
        ),
      ],
    );
  }

  ScheduleSummary? _seriesOf(
    List<ScheduleSummary> series,
    CalendarSession occurrence,
  ) {
    for (final schedule in series) {
      if (schedule.id == occurrence.scheduleId) return schedule;
    }
    return null;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard({required this.schedule, required this.onCancelled});

  final ScheduleSummary schedule;
  final Future<void> Function() onCancelled;

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: l10n.trainerCancelScheduleConfirmTitle,
      // Names the boundary: only what has not happened yet goes.
      message: l10n.trainerCancelScheduleConfirmMessage(schedule.remainingCount),
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref
          .read(cancelScheduleProvider)
          .call(schedule.clientId, schedule.id);
      await onCancelled();
      if (context.mounted) {
        AppSnackbar.showSuccess(context, title: l10n.trainerScheduleCancelledMessage);
      }
    } catch (error) {
      if (context.mounted) {
        AppSnackbar.showError(context, title: friendlyError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.cardAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        schedule.templateName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (schedule.isCancelled) ...[
                      const SizedBox(width: 8),
                      const OccurrenceStatusChip(status: OccurrenceStatus.cancelled),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  recurrenceSummary(
                    l10n,
                    locale,
                    recurrence: schedule.recurrence,
                    daysOfWeek: schedule.daysOfWeek,
                    startDate: schedule.startDate,
                    endDate: schedule.endDate,
                    timeOfDay: schedule.timeOfDay,
                  ),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.trainerScheduleCountsLabel(
                    schedule.doneCount,
                    schedule.missedCount,
                    schedule.remainingCount,
                  ),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (!schedule.isCancelled)
            IconButton(
              icon: const Icon(Icons.event_busy),
              color: scheme.error,
              tooltip: l10n.trainerCancelScheduleTooltip,
              onPressed: () => _cancel(context, ref, l10n),
            ),
        ],
      ),
    );
  }
}

/// One client's run of a multi-week program (docs/chat/41 T6).
///
/// Cancelling stops what has not happened yet; the sessions the client already
/// did stay on their record, same boundary as a schedule.
class _ProgramRunCard extends ConsumerWidget {
  const _ProgramRunCard({required this.run, required this.onCancelled});

  final ProgramAssignmentSummary run;
  final Future<void> Function() onCancelled;

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: l10n.trainerCancelProgramRunConfirmTitle,
      message: l10n.trainerCancelProgramRunConfirmMessage(run.remainingCount),
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(cancelProgramAssignmentProvider)(run.clientId, run.id);
      await onCancelled();
      if (context.mounted) {
        AppSnackbar.showSuccess(
          context,
          title: l10n.trainerProgramRunCancelledMessage,
        );
      }
    } catch (error) {
      if (context.mounted) {
        AppSnackbar.showError(context, title: friendlyError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.MMMd(locale);
    final weeks = weeksBetween(run.startDate, run.endDate);
    final currentWeek = currentProgramWeek(run.startDate, weeks);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.cardAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Icon(Icons.calendar_view_week, size: 18, color: scheme.tertiary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        run.programName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (run.isCancelled) ...[
                      const SizedBox(width: 8),
                      const OccurrenceStatusChip(status: OccurrenceStatus.cancelled),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (!run.isCancelled)
                      l10n.trainerProgramWeekOfLabel(currentWeek, weeks),
                    l10n.trainerDateRangeLabel(
                      dateFormat.format(run.startDate),
                      dateFormat.format(run.endDate),
                    ),
                  ].join(' · '),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.trainerScheduleCountsLabel(
                    run.doneCount,
                    run.missedCount,
                    run.remainingCount,
                  ),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (!run.isCancelled)
            IconButton(
              icon: const Icon(Icons.event_busy),
              color: scheme.error,
              tooltip: l10n.trainerCancelProgramRunTooltip,
              onPressed: () => _cancel(context, ref, l10n),
            ),
        ],
      ),
    );
  }
}

class _OccurrenceRow extends StatelessWidget {
  const _OccurrenceRow({
    required this.occurrence,
    required this.schedule,
    required this.onChanged,
  });

  final CalendarSession occurrence;
  final ScheduleSummary? schedule;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.cardAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final cancelled = await SessionPeekSheet.show(
            context,
            session: occurrence,
            client: null,
            scheduleRule: schedule,
          );
          if (cancelled ?? false) await onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        DateFormat.MMMEd(locale)
                            .format(occurrence.scheduledFor.toLocal()),
                        if (occurrence.scheduledTime != null)
                          formatScheduleTime(occurrence.scheduledTime!),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      occurrence.templateName ?? l10n.trainerFreeWorkoutLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OccurrenceStatusChip(status: occurrence.status),
            ],
          ),
        ),
      ),
    );
  }
}
