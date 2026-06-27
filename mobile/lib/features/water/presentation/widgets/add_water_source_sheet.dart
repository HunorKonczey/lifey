import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/water_source_controller.dart';
import '../../domain/water_source.dart';

/// Bottom sheet to create a water source, or edit one when [initial] is given.
class AddWaterSourceSheet extends ConsumerStatefulWidget {
  const AddWaterSourceSheet({super.key, this.initial});

  final WaterSource? initial;

  @override
  ConsumerState<AddWaterSourceSheet> createState() => _AddWaterSourceSheetState();
}

class _AddWaterSourceSheetState extends ConsumerState<AddWaterSourceSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _volume;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _volume = TextEditingController(
        text: widget.initial != null ? widget.initial!.volumeLiters.toString() : '');
  }

  @override
  void dispose() {
    _name.dispose();
    _volume.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return; // guard against a fast double-tap saving twice
    if (!_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    final volume = double.parse(_volume.text.replaceAll(',', '.'));

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final notifier = ref.read(waterSourceControllerProvider.notifier);
      if (_isEditing) {
        await notifier.updateSource(widget.initial!.clientId, name: name, volumeLiters: volume);
      } else {
        await notifier.addSource(name: name, volumeLiters: volume);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = AppLocalizations.of(context)!.couldNotSaveWaterSourceMessage);
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
            Text(_isEditing ? l10n.editWaterSourceTitle : l10n.newWaterSourceTitle,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.nameLabel,
                hintText: l10n.waterSourceNameHint,
                border: const OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.requiredFieldError : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _volume,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.volumeLabel,
                suffixText: 'L',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (parsed == null) return l10n.enterANumberError;
                if (parsed <= 0) return l10n.mustBeGreaterThanZeroError;
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.saveButton),
            ),
          ],
        ),
      ),
    );
  }
}
