import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../../shared/widgets/ds/metric_value.dart';
import '../../application/weight_controller.dart';
import '../../domain/weight_amount.dart';
import '../../domain/weight_entry.dart';

/// Opens the log-weight sheet over the shell (root navigator).
Future<void> showAddWeightSheet(BuildContext context) => showLifeySheet<void>(
      context: context,
      title: AppLocalizations.of(context)!.logWeightTitle,
      showClose: true,
      useRootNavigator: true,
      builder: (_) => const AddWeightSheet(),
    );

/// The body of the log-weight sheet (canvas Lifey 4 › 4.2; docs/redesign/
/// 77-mobile-redesign-plan.md R4.4): the weight at 72 px between 56 dp ±0.1
/// buttons (hold to repeat; tap the number to type it), yesterday's weigh-in as
/// a reference under it, the date, Save.
///
/// The value is whole grams ([WeightAmount]), so a hundred taps add exactly
/// ten kilograms. The canvas's "Also saved to Health Connect" line is not
/// drawn: the app only *imports* weight, so the claim would be false.
class AddWeightSheet extends ConsumerStatefulWidget {
  const AddWeightSheet({super.key});

  @override
  ConsumerState<AddWeightSheet> createState() => _AddWeightSheetState();
}

class _AddWeightSheetState extends ConsumerState<AddWeightSheet> {
  late WeightAmount _amount;
  late DateTime _date;
  final _now = DateTime.now();
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;

  /// Until the person changes the number it follows the latest weigh-in — the
  /// entries may arrive a frame after the sheet opens.
  bool _touched = false;
  bool _invalid = false;
  bool _submitting = false;
  String? _submitError;

  /// What a person weighs when there is nothing to start from.
  static const double _fallbackKg = 70;

  @override
  void initState() {
    super.initState();
    _date = _now;
    _amount = WeightAmount.fromKg(_fallbackKg);
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _commitText();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _step(int direction) {
    if (_editing) _commitText();
    setState(() {
      _touched = true;
      _amount = _amount.step(direction);
    });
    HapticFeedback.selectionClick();
  }

  void _startEditing() {
    final f = LifeyFormat.of(context);
    setState(() {
      _editing = true;
      _invalid = false;
      _text.text = f.decimal(_amount.kg, 1);
      _text.selection = TextSelection(baseOffset: 0, extentOffset: _text.text.length);
    });
    _focus.requestFocus();
  }

  void _commitText() {
    final parsed = WeightAmount.tryParse(_text.text);
    setState(() {
      _editing = false;
      _invalid = parsed == null;
      if (parsed != null) {
        _touched = true;
        _amount = parsed;
      }
    });
  }

  Future<void> _pickDate() async {
    if (_editing) _commitText();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: _now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return; // guard against a fast double-tap saving twice
    if (_editing) _commitText();
    if (_invalid) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await ref.read(weightControllerProvider.notifier).addEntry(date: _date, weight: _amount.kg);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _submitError = AppLocalizations.of(context)!.couldNotSaveEntryMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// "Yesterday 64.6 kg" — the weigh-in of the day before the selected date —
  /// or, without one, "Last 64.9 kg · Mon, Sep 21"; null with no earlier entry.
  String? _reference(AppLocalizations l10n, LifeyFormat f, List<WeightEntry> entries) {
    final day = DateTime(_date.year, _date.month, _date.day);
    final before = day.subtract(const Duration(days: 1));
    // Ordered date desc, recordedAt desc: the first match is the day's latest.
    for (final e in entries) {
      if (_isSameDay(e.date.toLocal(), before)) {
        return l10n.weightSheetYesterday(f.decimal(e.weight, 1));
      }
    }
    for (final e in entries) {
      final d = e.date.toLocal();
      if (DateTime(d.year, d.month, d.day).isBefore(day)) {
        return l10n.weightSheetLast(f.decimal(e.weight, 1), '${f.weekdayShort(d)}, ${f.shortDate(d)}');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final entries = ref.watch(weightControllerProvider).value ?? const <WeightEntry>[];
    if (!_touched && entries.isNotEmpty) _amount = WeightAmount.fromKg(entries.first.weight);
    final reference = _reference(l10n, f, entries);
    final today = _isSameDay(_date, _now);
    final dateLabel = today
        ? '${l10n.weightHistoryTodayLabel} · ${f.time(_now)}'
        : '${f.weekdayShort(_date)}, ${f.shortDate(_date)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            _StepButton(
              icon: Icons.remove_rounded,
              semanticsLabel: l10n.weightSheetDecrease,
              onStep: _amount.canStepDown ? () => _step(-1) : null,
            ),
            Expanded(
              child: Center(
                child: _editing
                    ? SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _text,
                          focusNode: _focus,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.done,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          style: AppType.number(56, color: p.text),
                          decoration: const InputDecoration(border: InputBorder.none, filled: false, isCollapsed: true),
                          onSubmitted: (_) => _commitText(),
                        ),
                      )
                    : Tooltip(
                        message: l10n.weightSheetTypeTooltip,
                        child: InkWell(
                          onTap: _startEditing,
                          borderRadius: AppRadius.controlAll,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4, horizontal: AppSpacing.s8),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: MetricValue(value: f.decimal(_amount.kg, 1), unit: 'kg', size: 72),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            _StepButton(
              icon: Icons.add_rounded,
              semanticsLabel: l10n.weightSheetIncrease,
              onStep: _amount.canStepUp ? () => _step(1) : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        if (_invalid)
          Text(
            l10n.enterANumberError,
            textAlign: TextAlign.center,
            style: t.bodyMedium!.copyWith(color: context.metricColors.negative),
          )
        else if (reference != null)
          Text(reference, textAlign: TextAlign.center, style: t.bodyMedium!.copyWith(color: p.text2)),
        const SizedBox(height: AppSpacing.s24),
        LifeyCard.nested(
          onTap: _submitting ? null : _pickDate,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s16),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 22, color: p.text),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  dateLabel,
                  style: t.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: p.text),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: p.text2),
            ],
          ),
        ),
        if (_submitError != null) ...[
          const SizedBox(height: AppSpacing.s12),
          Text(_submitError!, style: t.bodyMedium!.copyWith(color: context.metricColors.negative)),
        ],
        const SizedBox(height: AppSpacing.s24),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: _submitting || _invalid ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.saveButton),
          ),
        ),
      ],
    );
  }
}

/// A 56 dp ±0.1 button: a tap steps once, holding repeats (after 400 ms, every
/// 90 ms) so a two-kilo correction is not twenty taps.
class _StepButton extends StatefulWidget {
  const _StepButton({required this.icon, required this.semanticsLabel, required this.onStep});

  final IconData icon;
  final String semanticsLabel;

  /// Null at the limit: the button is disabled.
  final VoidCallback? onStep;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  Timer? _delay;
  Timer? _repeat;
  bool _repeated = false;

  void _stop() {
    _delay?.cancel();
    _repeat?.cancel();
    _delay = _repeat = null;
  }

  void _down() {
    _repeated = false;
    _delay = Timer(const Duration(milliseconds: 400), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) {
        final step = widget.onStep;
        if (step == null) return _stop();
        _repeated = true;
        step();
      });
    });
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = widget.onStep != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: p.control,
        borderRadius: AppRadius.controlAll,
        child: InkWell(
          borderRadius: AppRadius.controlAll,
          onTapDown: enabled ? (_) => _down() : null,
          onTapUp: (_) => _stop(),
          onTapCancel: _stop,
          onTap: enabled
              ? () {
                  if (!_repeated) widget.onStep!();
                }
              : null,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(widget.icon, size: 28, color: enabled ? p.text : p.text3),
          ),
        ),
      ),
    );
  }
}
