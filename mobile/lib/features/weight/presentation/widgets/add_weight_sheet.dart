import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
      setState(() => _submitError = "Couldn't save the entry. Please try again.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add weight', style: Theme.of(context).textTheme.titleLarge),
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
              decoration: const InputDecoration(
                labelText: 'Weight',
                suffixText: 'kg',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.replaceAll(',', '.').trim() ?? '';
                final parsed = double.tryParse(text);
                if (parsed == null) return 'Enter a number';
                if (parsed <= 0) return 'Must be greater than 0';
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
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
