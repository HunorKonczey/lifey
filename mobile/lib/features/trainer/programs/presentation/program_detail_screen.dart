import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../schedule/application/recurrence_text.dart';
import '../application/programs_controller.dart';
import '../domain/program.dart';
import 'widgets/assign_program_sheet.dart';
import 'widgets/edit_on_web_notice.dart';

/// One program, week by week (frame G2).
///
/// Collapsible weeks rather than a grid: on a phone, twelve columns of seven
/// cells is unreadable, while a week you can open one at a time is exactly how
/// a trainer talks about a block anyway.
class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.programId});

  final int programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final program = ref.watch(programProvider(programId));

    return Scaffold(
      appBar: AppBar(
        title: Text(program.value?.name ?? l10n.trainerProgramsTitle),
      ),
      floatingActionButton: program.hasValue
          ? FloatingActionButton.extended(
              heroTag: null,
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              foregroundColor: Theme.of(context).colorScheme.onTertiary,
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.trainerStartProgramButton),
              onPressed: () => _assign(context, ref, program.requireValue),
            )
          : null,
      body: program.when(
        data: (program) => _Body(program: program),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(programProvider(programId)),
        ),
      ),
    );
  }

  Future<void> _assign(BuildContext context, WidgetRef ref, Program program) async {
    final result = await AssignProgramSheet.show(
      context,
      programId: program.id,
      programName: program.name,
      weeksCount: program.weeksCount,
    );
    if (result == null || !context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMMMd(locale);
    // Says what was actually written: the run's dates and how many sessions
    // just landed in someone's calendar.
    AppSnackbar.showSuccess(
      context,
      title: l10n.trainerProgramStartedMessage(result.occurrenceCount),
      subtitle: l10n.trainerDateRangeLabel(
        dateFormat.format(result.startDate.toLocal()),
        dateFormat.format(result.endDate.toLocal()),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 96,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.trainerProgramWeeksLabel(program.weeksCount),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        for (var week = 1; week <= program.weeksCount; week++)
          _WeekSection(
            weekNumber: week,
            slots: program.slotsOfWeek(week),
            // The first week opens by default — it is the one being read most
            // of the time, and twelve collapsed rows with nothing showing is
            // a screen that tells you nothing.
            initiallyExpanded: week == 1,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: EditOnWebNotice(programId: program.id),
        ),
      ],
    );
  }
}

class _WeekSection extends StatelessWidget {
  const _WeekSection({
    required this.weekNumber,
    required this.slots,
    required this.initiallyExpanded,
  });

  final int weekNumber;
  final List<ProgramSlot> slots;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final weekdayFormat = DateFormat.EEEE(locale);

    return Theme(
      // The default divider on an ExpansionTile draws a line across every
      // week; the sections are already separated by their own headers.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(
          l10n.trainerProgramWeekLabel(weekNumber),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          slots.isEmpty
              ? l10n.trainerProgramRestWeekLabel
              : l10n.trainerProgramSessionCountLabel(slots.length),
          style: theme.textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          if (slots.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.trainerProgramRestWeekMessage,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            for (final slot in slots)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: AppRadius.cardAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        weekdayFormat
                            .format(DateTime(2024, 1, slot.dayOfWeek.isoNumber)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot.templateName,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (slot.timeOfDay != null)
                            Text(
                              formatScheduleTime(slot.timeOfDay!),
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          if ((slot.note ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                slot.note!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
