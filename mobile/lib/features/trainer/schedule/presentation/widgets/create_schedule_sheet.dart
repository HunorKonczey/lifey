import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/network/error_message.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../workouts/application/workout_template_controller.dart';
import '../../../../workouts/domain/workout_template.dart';
import '../../application/recurrence_text.dart';
import '../../data/schedule_repository.dart';
import '../../domain/occurrence_generator.dart';
import '../../domain/schedule.dart';

/// Book a client in (frame F4).
///
/// The order is the order the trainer thinks in: which workout, from when,
/// at what time, how often, until when. The summary at the bottom answers the
/// question the form otherwise leaves hanging — *how many sessions is this
/// actually going to create* — before anything is sent.
class CreateScheduleSheet extends ConsumerStatefulWidget {
  const CreateScheduleSheet({super.key, required this.clientId});

  final int clientId;

  /// Returns true when a schedule was created.
  static Future<bool?> show(BuildContext context, {required int clientId}) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: CreateScheduleSheet(clientId: clientId),
      ),
    );
  }

  @override
  ConsumerState<CreateScheduleSheet> createState() => _CreateScheduleSheetState();
}

class _CreateScheduleSheetState extends ConsumerState<CreateScheduleSheet> {
  WorkoutTemplate? _template;
  ScheduleRecurrence _recurrence = ScheduleRecurrence.once;
  final Set<ScheduleWeekday> _days = {};
  late DateTime _startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  late DateTime _endDate = _startDate.add(const Duration(days: 27));
  ScheduleTime? _time;

  bool _submitting = false;
  String? _error;

  OccurrencePreview get _preview => generateOccurrences(
        recurrence: _recurrence,
        daysOfWeek: _days.toList(),
        startDate: _startDate,
        endDate: _endDate,
      );

  bool get _canSubmit =>
      _template?.id != null && _preview.isValid && !_submitting;

  Future<void> _pickDate({required bool start}) async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _startDate : _endDate,
      // The backend refuses a start in the past, so the picker does not offer
      // one — a rejected request is a worse way to learn that.
      firstDate: start ? today : _startDate,
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time == null
          ? const TimeOfDay(hour: 18, minute: 0)
          : TimeOfDay(hour: _time!.hour, minute: _time!.minute),
    );
    if (picked == null) return;
    setState(() => _time = ScheduleTime(picked.hour, picked.minute));
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(scheduleRepositoryProvider).createSchedule(
            clientId: widget.clientId,
            templateId: _template!.id!,
            recurrence: _recurrence,
            daysOfWeek: _days.toList(),
            startDate: _startDate,
            endDate: _endDate,
            timeOfDay: _time,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMMMd(locale);
    final templates = ref.watch(workoutTemplateControllerProvider).value ?? const [];
    final assignable = templates.where((t) => t.id != null).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.trainerScheduleWorkoutTitle,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                // ── Template ───────────────────────────────────────────
                if (assignable.isEmpty)
                  Text(
                    l10n.trainerNoTemplatesToScheduleMessage,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  )
                else
                  DropdownButtonFormField<WorkoutTemplate>(
                    initialValue: _template,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.trainerScheduleTemplateLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final template in assignable)
                        DropdownMenuItem(
                          value: template,
                          child: Text(template.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) => setState(() => _template = value),
                  ),
                const SizedBox(height: 14),

                // ── Recurrence ─────────────────────────────────────────
                Text(
                  l10n.trainerScheduleRepeatLabel,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final recurrence in ScheduleRecurrence.values)
                      ChoiceChip(
                        label: Text(switch (recurrence) {
                          ScheduleRecurrence.once => l10n.trainerRecurrenceOnceLabel,
                          ScheduleRecurrence.daily => l10n.trainerRecurrenceDailyLabel,
                          ScheduleRecurrence.weekly => l10n.trainerRecurrenceWeeklyLabel,
                        }),
                        selected: _recurrence == recurrence,
                        showCheckmark: false,
                        selectedColor: scheme.tertiaryContainer,
                        onSelected: (_) => setState(() => _recurrence = recurrence),
                      ),
                  ],
                ),
                if (_recurrence == ScheduleRecurrence.weekly) ...[
                  const SizedBox(height: 10),
                  _WeekdayChips(
                    selected: _days,
                    onToggle: (day) => setState(() {
                      if (!_days.remove(day)) _days.add(day);
                    }),
                  ),
                ],
                const SizedBox(height: 14),

                // ── When ───────────────────────────────────────────────
                _FieldRow(
                  icon: Icons.event,
                  label: l10n.trainerScheduleStartsLabel,
                  value: dateFormat.format(_startDate),
                  onTap: () => _pickDate(start: true),
                ),
                if (_recurrence != ScheduleRecurrence.once)
                  _FieldRow(
                    icon: Icons.event_repeat,
                    label: l10n.trainerScheduleUntilLabel,
                    value: dateFormat.format(_endDate),
                    onTap: () => _pickDate(start: false),
                  ),
                _FieldRow(
                  icon: Icons.schedule,
                  label: l10n.trainerScheduleTimeLabel,
                  value: _time == null
                      ? l10n.trainerScheduleNoTimeLabel
                      : formatScheduleTime(_time!),
                  onTap: _pickTime,
                  onClear: _time == null ? null : () => setState(() => _time = null),
                ),
                const SizedBox(height: 14),

                // ── What this will create ──────────────────────────────
                _Summary(preview: _preview, recurrence: _recurrence, days: _days),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 8,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
            ),
            child: Row(
              children: [
                if (_submitting)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Expanded(
                  child: FilledButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.tertiary,
                      foregroundColor: scheme.onTertiary,
                    ),
                    child: Text(l10n.trainerScheduleCreateButton),
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

/// Mon–Sun as chips, in the locale's own short names (frame F4).
class _WeekdayChips extends StatelessWidget {
  const _WeekdayChips({required this.selected, required this.onToggle});

  final Set<ScheduleWeekday> selected;
  final ValueChanged<ScheduleWeekday> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final format = DateFormat.E(locale);

    return Wrap(
      spacing: 6,
      children: [
        for (final day in ScheduleWeekday.values)
          FilterChip(
            label: Text(format.format(DateTime(2024, 1, day.isoNumber))),
            selected: selected.contains(day),
            showCheckmark: false,
            selectedColor: scheme.tertiaryContainer,
            onSelected: (_) => onToggle(day),
          ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(label, style: theme.textTheme.bodySmall),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      trailing: onClear == null
          ? null
          : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClear),
      onTap: onTap,
    );
  }
}

/// "This creates 12 sessions, Aug 5 – Oct 28", or why it creates none.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.preview,
    required this.recurrence,
    required this.days,
  });

  final OccurrencePreview preview;
  final ScheduleRecurrence recurrence;
  final Set<ScheduleWeekday> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.MMMd(locale);

    final (text, isProblem) = switch (preview.problem) {
      OccurrenceProblem.none => (
          recurrence == ScheduleRecurrence.weekly && days.isEmpty
              ? l10n.trainerPickAtLeastOneDayMessage
              : l10n.trainerNoOccurrencesInRangeMessage,
          true,
        ),
      OccurrenceProblem.tooMany => (
          l10n.trainerTooManyOccurrencesMessage(
            preview.count,
            maxScheduleOccurrences,
          ),
          true,
        ),
      null => (
          preview.count == 1
              ? l10n.trainerOneOccurrenceSummary(dateFormat.format(preview.first!))
              : l10n.trainerOccurrenceCountSummary(
                  preview.count,
                  dateFormat.format(preview.first!),
                  dateFormat.format(preview.last!),
                ),
          false,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isProblem ? scheme.errorContainer : scheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            isProblem ? Icons.error_outline : Icons.event_available,
            size: 18,
            color: isProblem ? scheme.onErrorContainer : scheme.tertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isProblem ? scheme.onErrorContainer : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
