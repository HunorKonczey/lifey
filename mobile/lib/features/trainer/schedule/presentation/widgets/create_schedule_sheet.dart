import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/format/lifey_format.dart';
import '../../../../../core/network/error_message.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../../shared/widgets/ds/lifey_segmented.dart';
import '../../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../../../shared/widgets/ds/list_group.dart';
import '../../../../../shared/widgets/ds/tinted_chip.dart';
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
    return showLifeySheet<bool>(
      context: context,
      title: AppLocalizations.of(context)!.trainerScheduleWorkoutTitle,
      useRootNavigator: true,
      builder: (_) => CreateScheduleSheet(clientId: clientId),
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
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final templates = ref.watch(workoutTemplateControllerProvider).value ?? const [];
    final assignable = templates.where((t) => t.id != null).toList();

    String recurrenceLabel(ScheduleRecurrence recurrence) => switch (recurrence) {
          ScheduleRecurrence.once => l10n.trainerRecurrenceOnceLabel,
          ScheduleRecurrence.daily => l10n.trainerRecurrenceDailyLabel,
          ScheduleRecurrence.weekly => l10n.trainerRecurrenceWeeklyLabel,
        };

    // The sheet's own frame (title, handle, keyboard inset, scrolling) comes
    // from showLifeySheet; this is only what goes in it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // -- Template
        if (assignable.isEmpty)
          Text(
            l10n.trainerNoTemplatesToScheduleMessage,
            style: theme.textTheme.bodySmall?.copyWith(color: p.text2),
          )
        else
          DropdownButtonFormField<WorkoutTemplate>(
            initialValue: _template,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.trainerScheduleTemplateLabel),
            items: [
              for (final template in assignable)
                DropdownMenuItem(
                  value: template,
                  child: Text(template.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _template = value),
          ),
        const SizedBox(height: AppSpacing.s16),

        // -- Recurrence
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
          child: Text(
            l10n.trainerScheduleRepeatLabel,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: p.text2),
          ),
        ),
        LifeySegmented<ScheduleRecurrence>(
          segments: [for (final recurrence in ScheduleRecurrence.values) (recurrence, recurrenceLabel(recurrence))],
          selected: _recurrence,
          onChanged: (recurrence) => setState(() => _recurrence = recurrence),
        ),
        if (_recurrence == ScheduleRecurrence.weekly) ...[
          const SizedBox(height: AppSpacing.s12),
          _WeekdayChips(
            selected: _days,
            onToggle: (day) => setState(() {
              if (!_days.remove(day)) _days.add(day);
            }),
          ),
        ],
        const SizedBox(height: AppSpacing.s16),

        // -- When
        ListGroup(
          dividerInset: 72,
          children: [
            _FieldRow(
              icon: Icons.event_rounded,
              label: l10n.trainerScheduleStartsLabel,
              value: f.fullDate(_startDate),
              onTap: () => _pickDate(start: true),
            ),
            if (_recurrence != ScheduleRecurrence.once)
              _FieldRow(
                icon: Icons.event_repeat_rounded,
                label: l10n.trainerScheduleUntilLabel,
                value: f.fullDate(_endDate),
                onTap: () => _pickDate(start: false),
              ),
            _FieldRow(
              icon: Icons.schedule_rounded,
              label: l10n.trainerScheduleTimeLabel,
              value: _time == null ? l10n.trainerScheduleNoTimeLabel : formatScheduleTime(_time!),
              onTap: _pickTime,
              onClear: _time == null ? null : () => setState(() => _time = null),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),

        // -- What this will create
        _Summary(preview: _preview, recurrence: _recurrence, days: _days),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.s12),
          Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
        ],
        const SizedBox(height: AppSpacing.s20),
        Row(
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
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(l10n.trainerScheduleCreateButton),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeekdayChips extends StatelessWidget {
  const _WeekdayChips({required this.selected, required this.onToggle});

  final Set<ScheduleWeekday> selected;
  final ValueChanged<ScheduleWeekday> onToggle;

  @override
  Widget build(BuildContext context) {
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
    return ListRow(
      leading: ListIconHolder(icon: icon, color: Theme.of(context).colorScheme.primary, size: 40),
      title: label,
      subtitle: value,
      trailing: onClear == null
          ? Icon(Icons.chevron_right_rounded, size: 20, color: context.palette.text3)
          : IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onClear,
            ),
      onTap: onTap,
    );
  }
}

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
    final p = context.palette;
    final mc = context.metricColors;
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

    // A problem is the warning tint (the same one "missed" uses); a fine plan
    // is just a quiet line on the nested surface.
    return LifeyCard.nested(
      color: isProblem ? mc.calories.withValues(alpha: TintedChip.tintAlpha(theme.brightness)) : null,
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Row(
        children: [
          Icon(
            isProblem ? Icons.error_outline_rounded : Icons.event_available_rounded,
            size: 18,
            color: isProblem ? mc.calories : theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: p.text),
            ),
          ),
        ],
      ),
    );
  }
}
