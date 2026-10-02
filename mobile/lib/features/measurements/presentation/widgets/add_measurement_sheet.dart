import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../application/body_measurement_controller.dart';
import '../../domain/body_measurement.dart';
import '../../domain/measurement_series.dart';
import 'measurement_site_chips.dart';

/// Opens the log-measurement sheet over the current route. [initialSite]
/// preselects the chip (the site the screen is showing).
Future<void> showAddMeasurementSheet(BuildContext context, {required MeasurementSite initialSite}) =>
    showLifeySheet<void>(
      context: context,
      title: AppLocalizations.of(context)!.bodyMeasurementsLogTitle,
      showClose: true,
      useRootNavigator: true,
      builder: (_) => AddMeasurementSheet(initialSite: initialSite),
    );

/// Site chips, a centimetre field, the date, Save (docs/80 §7 P3).
class AddMeasurementSheet extends ConsumerStatefulWidget {
  const AddMeasurementSheet({super.key, required this.initialSite});

  final MeasurementSite initialSite;

  @override
  ConsumerState<AddMeasurementSheet> createState() => _AddMeasurementSheetState();
}

class _AddMeasurementSheetState extends ConsumerState<AddMeasurementSheet> {
  late MeasurementSite _site = widget.initialSite;
  final _now = DateTime.now();
  late DateTime _date = _now;
  final _text = TextEditingController();
  bool _invalid = false;
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: _now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final cm = parseMeasurementCm(_text.text);
    if (cm == null) {
      setState(() => _invalid = true);
      return;
    }
    setState(() {
      _invalid = false;
      _submitting = true;
      _submitError = null;
    });
    try {
      await ref.read(bodyMeasurementControllerProvider.notifier).add(date: _date, site: _site, valueCm: cm);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _submitError = AppLocalizations.of(context)!.couldNotSaveEntryMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final dateLabel = _isSameDay(_date, _now)
        ? l10n.weightHistoryTodayLabel
        : '${f.weekdayShort(_date)}, ${f.shortDate(_date)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s8),
        MeasurementSiteChips(
          selected: _site,
          onSelected: _submitting ? (_) {} : (s) => setState(() => _site = s),
        ),
        const SizedBox(height: AppSpacing.s24),
        TextField(
          controller: _text,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: AppType.number(48, color: p.text),
          decoration: InputDecoration(
            hintText: '0',
            suffixText: 'cm',
            labelText: l10n.bodyMeasurementValueLabel,
            errorText: _invalid ? l10n.bodyMeasurementOutOfRangeError : null,
          ),
          onChanged: (_) {
            if (_invalid) setState(() => _invalid = false);
          },
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.s16),
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
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.saveButton),
          ),
        ),
      ],
    );
  }
}
