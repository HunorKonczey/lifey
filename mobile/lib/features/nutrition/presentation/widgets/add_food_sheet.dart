import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../application/barcode_lookup_controller.dart';
import '../../application/food_controller.dart';
import '../../domain/barcode_lookup_result.dart';
import '../../domain/food.dart';
import '../barcode_scanner_screen.dart';

/// Bottom sheet form to create a food, or edit one when [food] is provided.
///
/// Pass [initialBarcode] to skip the in-sheet scan step and immediately
/// trigger a backend barcode lookup on open (used when the caller already
/// ran the camera before showing the sheet).
/// Pops on success.
class AddFoodSheet extends ConsumerStatefulWidget {
  const AddFoodSheet({super.key, this.food, this.initialBarcode});

  final Food? food;
  final String? initialBarcode;

  @override
  ConsumerState<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends ConsumerState<AddFoodSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  bool _submitting = false;
  bool _scanning = false;
  String? _error;
  String? _barcode;
  Timer? _autoSaveDebounce;

  bool get _isEditing => widget.food != null;

  @override
  void initState() {
    super.initState();
    final food = widget.food;
    String num(double? v) => v == null ? '' : _trim(v);
    _name = TextEditingController(text: food?.name ?? '');
    _calories = TextEditingController(
        text: food == null ? '' : _trim(food.caloriesPer100g));
    _protein = TextEditingController(
        text: food == null ? '' : _trim(food.proteinPer100g));
    _carbs = TextEditingController(text: num(food?.carbsPer100g));
    _fat = TextEditingController(text: num(food?.fatPer100g));
    _barcode = food?.barcode;

    if (_isEditing) {
      _name.addListener(_scheduleAutoSave);
      _calories.addListener(_scheduleAutoSave);
      _protein.addListener(_scheduleAutoSave);
      _carbs.addListener(_scheduleAutoSave);
      _fat.addListener(_scheduleAutoSave);
    }

    if (widget.initialBarcode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _lookupBarcode(widget.initialBarcode!);
      });
    }
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  double? _parse(String text) =>
      double.tryParse(text.replaceAll(',', '.').trim());

  String? _validateRequiredNumber(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final parsed = _parse(value ?? '');
    if (parsed == null) return l10n.enterANumberError;
    if (parsed < 0) return l10n.mustBeZeroOrMoreError;
    return null;
  }

  String? _validateOptionalNumber(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    final l10n = AppLocalizations.of(context)!;
    final parsed = _parse(value!);
    if (parsed == null) return l10n.enterANumberError;
    if (parsed < 0) return l10n.mustBeZeroOrMoreError;
    return null;
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) return;
    await _lookupBarcode(barcode);
  }

  Future<void> _lookupBarcode(String barcode) async {
    setState(() => _scanning = true);
    try {
      await ref.read(barcodeLookupControllerProvider.notifier).lookup(barcode);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      switch (ref.read(barcodeLookupControllerProvider)) {
        case BarcodeLookupFound(result: final result):
          if (result.source == BarcodeSource.local) {
            final existing =
                await ref.read(foodControllerProvider.notifier).findByBarcode(barcode);
            if (!mounted) return;
            if (existing != null) {
              AppSnackbar.showInfo(context, title: l10n.foodAlreadyExistsMessage);
              final navigator = Navigator.of(context, rootNavigator: true);
              navigator.pop();
              showModalBottomSheet<void>(
                context: navigator.context,
                useRootNavigator: true,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => AddFoodSheet(food: existing),
              );
              return;
            }
          }
          setState(() {
            _name.text = result.name;
            _calories.text = _trim(result.caloriesPer100g);
            _protein.text = _trim(result.proteinPer100g);
            _carbs.text = result.carbsPer100g == null ? '' : _trim(result.carbsPer100g!);
            _fat.text = result.fatPer100g == null ? '' : _trim(result.fatPer100g!);
            _barcode = result.barcode;
          });
        case BarcodeLookupNotFound():
          setState(() => _barcode = barcode);
          AppSnackbar.showInfo(context, title: l10n.noBarcodeMatchMessage);
        case BarcodeLookupOffline():
          AppSnackbar.showError(context, title: l10n.offlineCantLookupMessage);
        case BarcodeLookupIdle():
        case BarcodeLookupLoading():
          break;
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: AppLocalizations.of(context)!.couldNotLookupBarcodeMessage,
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 500), _autoSaveInBackground);
  }

  Future<void> _autoSaveInBackground() async {
    if (_submitting) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final calories = _parse(_calories.text);
    if (calories == null || calories < 0) return;
    final protein = _parse(_protein.text);
    if (protein == null || protein < 0) return;
    final carbsText = _carbs.text.trim();
    if (carbsText.isNotEmpty) {
      final v = _parse(carbsText);
      if (v == null || v < 0) return;
    }
    final fatText = _fat.text.trim();
    if (fatText.isNotEmpty) {
      final v = _parse(fatText);
      if (v == null || v < 0) return;
    }
    try {
      await ref.read(foodControllerProvider.notifier).updateFood(
        widget.food!.clientId,
        name: name,
        calories: calories,
        protein: protein,
        carbs: carbsText.isEmpty ? null : _parse(carbsText),
        fat: fatText.isEmpty ? null : _parse(fatText),
        barcode: _barcode,
      );
    } catch (_) {
      // Silent fail — the explicit save button surfaces errors.
    }
  }

  Future<void> _submit() async {
    if (_submitting) return; // guard against a fast double-tap saving twice
    if (!_formKey.currentState!.validate()) return;
    final carbsText = _carbs.text.trim();
    final fatText = _fat.text.trim();
    final name = _name.text.trim();

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final notifier = ref.read(foodControllerProvider.notifier);
      final calories = _parse(_calories.text)!;
      final protein = _parse(_protein.text)!;
      final carbs = carbsText.isEmpty ? null : _parse(carbsText);
      final fat = fatText.isEmpty ? null : _parse(fatText);

      if (_isEditing) {
        await notifier.updateFood(widget.food!.clientId,
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            barcode: _barcode);
      } else {
        await notifier.addFood(
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            barcode: _barcode);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // A duplicate name only surfaces once this syncs (no synchronous 409
      // anymore — the write already landed locally before any network call).
      setState(() => _error = AppLocalizations.of(context)!.couldNotSaveFoodMessage);
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
            Text(_isEditing ? l10n.editFoodTitle : l10n.addFoodTitle,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l10n.valuesPerHundredGrams,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            if (!_isEditing) ...[
              OutlinedButton.icon(
                onPressed: _scanning ? null : _scanBarcode,
                icon: _scanning
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code_scanner),
                label: Text(_scanning ? l10n.lookingUpStatus : l10n.scanBarcodeButton),
              ),
              if (_barcode != null) ...[
                const SizedBox(height: 4),
                Text(l10n.linkedToBarcodeMessage(_barcode!),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.nameLabel,
                border: const OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.requiredFieldError : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _calories,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.caloriesLabel,
                      suffixText: 'kcal',
                      border: const OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    validator: _validateRequiredNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _protein,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.proteinLabel,
                      suffixText: 'g',
                      border: const OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    validator: _validateRequiredNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _carbs,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.carbsOptionalLabel,
                      suffixText: 'g',
                      border: const OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    validator: _validateOptionalNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _fat,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.fatOptionalLabel,
                      suffixText: 'g',
                      border: const OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: _validateOptionalNumber,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                  : Text(_isEditing ? l10n.saveChangesButton : l10n.saveButton),
            ),
          ],
        ),
      ),
    );
  }
}
