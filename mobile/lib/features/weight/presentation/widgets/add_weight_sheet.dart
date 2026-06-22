import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/weight_controller.dart';

/// Bottom sheet form for adding a weight entry. Pops on success.
class AddWeightSheet extends ConsumerStatefulWidget {
  const AddWeightSheet({super.key});

  @override
  ConsumerState<AddWeightSheet> createState() => _AddWeightSheetState();
}

class _AddWeightSheetState extends ConsumerState<AddWeightSheet> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _submitting = false;
  String? _submitError;

  static final _dateLabel = DateFormat('EEE, MMM d, yyyy');

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return; // guard against a fast double-tap saving twice
    if (!_formKey.currentState!.validate()) return;
    final weight = double.parse(_weightController.text.replaceAll(',', '.'));

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await ref
          .read(weightControllerProvider.notifier)
          .addEntry(date: _date, weight: weight);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _submitError = AppLocalizations.of(context)!.couldNotSaveEntryMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.addWeightTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(_dateLabel.format(_date)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weightController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.weightTitle,
                suffixText: 'kg',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.replaceAll(',', '.').trim() ?? '';
                final parsed = double.tryParse(text);
                if (parsed == null) return l10n.enterANumberError;
                if (parsed <= 0) return l10n.mustBeGreaterThanZeroError;
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 8),
              Text(
                _submitError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.saveButton),
            ),
          ],
        ),
      ),
    );
  }
}
