import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../application/barcode_lookup_controller.dart';
import '../../application/food_controller.dart';
import '../../application/off_search_controller.dart';
import '../../domain/barcode_lookup_result.dart';
import '../../domain/food.dart';
import '../../domain/off_search.dart';
import '../barcode_scanner_screen.dart';
import 'off_search_option.dart';
import '../../../../core/format/parse_decimal.dart';

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
  late final TextEditingController _fiber;
  late final TextEditingController _sugar;

  /// The named servings being edited (LIF-146): a name and a grams field per row; at most [_maxServings].
  final List<_ServingRow> _servings = [];
  static const _maxServings = 10;
  bool _submitting = false;
  bool _scanning = false;
  String? _error;
  String? _barcode;
  Timer? _autoSaveDebounce;

  /// A product from OpenFoodFacts has filled the form (docs/84): the results list stays closed until the name is edited again.
  bool _offPicked = false;

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
    _fiber = TextEditingController(text: num(food?.fiberPer100g));
    _sugar = TextEditingController(text: num(food?.sugarPer100g));
    for (final s in food?.servings ?? const <FoodServing>[]) {
      _servings.add(_ServingRow(s.name, _trim(s.grams)));
    }
    _barcode = food?.barcode;

    if (_isEditing) {
      _name.addListener(_scheduleAutoSave);
      _calories.addListener(_scheduleAutoSave);
      _protein.addListener(_scheduleAutoSave);
      _carbs.addListener(_scheduleAutoSave);
      _fat.addListener(_scheduleAutoSave);
      _fiber.addListener(_scheduleAutoSave);
      _sugar.addListener(_scheduleAutoSave);
      for (final row in _servings) {
        row.addListener(_scheduleAutoSave);
      }
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
    _fiber.dispose();
    _sugar.dispose();
    for (final row in _servings) {
      row.dispose();
    }
    super.dispose();
  }

  double? _parse(String text) => parseDecimal(text);

  void _addServing() {
    if (_servings.length >= _maxServings) return;
    final row = _ServingRow('', '');
    if (_isEditing) row.addListener(_scheduleAutoSave);
    setState(() => _servings.add(row));
  }

  void _removeServing(_ServingRow row) {
    setState(() => _servings.remove(row));
    row.dispose();
    if (_isEditing) _scheduleAutoSave();
  }

  /// The servings to save: the rows with both a name and a positive amount. A row left completely blank is dropped; a half-filled
  /// one makes this null (the form is not valid yet).
  List<FoodServing>? _collectServings() {
    final result = <FoodServing>[];
    for (final row in _servings) {
      final name = row.name.text.trim();
      final gramsText = row.grams.text.trim();
      if (name.isEmpty && gramsText.isEmpty) continue;
      final grams = _parse(gramsText);
      if (name.isEmpty || grams == null || grams <= 0 || grams > 5000) return null;
      result.add(FoodServing(name: name, grams: grams));
    }
    return result;
  }

  String? _validateServingName(_ServingRow row, String? value) {
    final l10n = AppLocalizations.of(context)!;
    final grams = row.grams.text.trim();
    if ((value ?? '').trim().isEmpty && grams.isNotEmpty) return l10n.servingNameRequiredError;
    return null;
  }

  String? _validateServingGrams(_ServingRow row, String? value) {
    final l10n = AppLocalizations.of(context)!;
    final text = (value ?? '').trim();
    if (text.isEmpty) return row.name.text.trim().isEmpty ? null : l10n.enterANumberError;
    final parsed = _parse(text);
    if (parsed == null) return l10n.enterANumberError;
    if (parsed <= 0 || parsed > 5000) return l10n.servingGramsRangeError;
    return null;
  }

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

  /// What is typed in the name field goes to the OpenFoodFacts search (which does nothing unless the box is ticked and enough is
  /// typed); a change also brings the results back after a product was picked.
  void _nameChanged(String text) {
    setState(() => _offPicked = false);
    final lang = offSearchLang(Localizations.localeOf(context).languageCode);
    ref.read(offSearchControllerProvider.notifier).queryChanged(text, lang);
  }

  /// A tap on an OpenFoodFacts product: it fills the form — name, calories, protein, carbs and fat (blank when OpenFoodFacts has
  /// none) and the barcode. Nothing is saved; the user checks the values and saves as usual.
  void _pickOff(OffSearchItem item) {
    FocusScope.of(context).unfocus();
    setState(() {
      _name.text = item.name;
      _calories.text = _trim(item.caloriesPer100g);
      _protein.text = _trim(item.proteinPer100g);
      _carbs.text = item.carbsPer100g == null ? '' : _trim(item.carbsPer100g!);
      _fat.text = item.fatPer100g == null ? '' : _trim(item.fatPer100g!);
      _fiber.text = item.fiberPer100g == null ? '' : _trim(item.fiberPer100g!);
      _sugar.text = item.sugarPer100g == null ? '' : _trim(item.sugarPer100g!);
      _barcode = item.barcode;
      _offPicked = true;
    });
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
            final existing = await ref
                .read(foodControllerProvider.notifier)
                .findByBarcode(barcode);
            if (!mounted) return;
            if (existing != null) {
              AppSnackbar.showInfo(context,
                  title: l10n.foodAlreadyExistsMessage);
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
            _carbs.text =
                result.carbsPer100g == null ? '' : _trim(result.carbsPer100g!);
            _fat.text =
                result.fatPer100g == null ? '' : _trim(result.fatPer100g!);
            _fiber.text = result.fiberPer100g == null ? '' : _trim(result.fiberPer100g!);
            _sugar.text = result.sugarPer100g == null ? '' : _trim(result.sugarPer100g!);
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
    _autoSaveDebounce =
        Timer(const Duration(milliseconds: 500), _autoSaveInBackground);
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
    final fiberText = _fiber.text.trim();
    if (fiberText.isNotEmpty) {
      final v = _parse(fiberText);
      if (v == null || v < 0) return;
    }
    final sugarText = _sugar.text.trim();
    if (sugarText.isNotEmpty) {
      final v = _parse(sugarText);
      if (v == null || v < 0) return;
    }
    final servings = _collectServings();
    if (servings == null) return;
    try {
      await ref.read(foodControllerProvider.notifier).updateFood(
            widget.food!.clientId,
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbsText.isEmpty ? null : _parse(carbsText),
            fat: fatText.isEmpty ? null : _parse(fatText),
            fiber: fiberText.isEmpty ? null : _parse(fiberText),
            sugar: sugarText.isEmpty ? null : _parse(sugarText),
            servings: servings,
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
    final fiberText = _fiber.text.trim();
    final sugarText = _sugar.text.trim();
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
      final fiber = fiberText.isEmpty ? null : _parse(fiberText);
      final sugar = sugarText.isEmpty ? null : _parse(sugarText);
      final servings = _collectServings() ?? const <FoodServing>[];

      if (_isEditing) {
        await notifier.updateFood(widget.food!.clientId,
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            servings: servings,
            barcode: _barcode);
      } else {
        await notifier.addFood(
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            servings: servings,
            barcode: _barcode);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // A duplicate name only surfaces once this syncs (no synchronous 409
      // anymore — the write already landed locally before any network call).
      setState(
          () => _error = AppLocalizations.of(context)!.couldNotSaveFoodMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final l10n = AppLocalizations.of(context)!;
    final offState = ref.watch(offSearchControllerProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: Form(
        key: _formKey,
        // Scrolls: with the OpenFoodFacts results open the form is taller than a phone.
        child: SingleChildScrollView(
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
                  label: Text(_scanning
                      ? l10n.lookingUpStatus
                      : l10n.scanBarcodeButton),
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
                onChanged: _isEditing ? null : _nameChanged,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.requiredFieldError
                    : null,
              ),
              if (!_isEditing) ...[
                const OffSearchToggle(),
                if (offState.enabled &&
                    !_offPicked &&
                    _name.text.trim().isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child:
                          OffResultsBody(typed: _name.text, onPick: _pickOff),
                    ),
                  ),
                if (offState.enabled && _offPicked)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l10n.offSearchFilled,
                        key: const ValueKey('off-filled'),
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
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
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
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
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
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
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                      validator: _validateOptionalNumber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fat,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.fatOptionalLabel,
                        suffixText: 'g',
                        border: const OutlineInputBorder(),
                      ),
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                      validator: _validateOptionalNumber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fiber,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.fiberOptionalLabel,
                        suffixText: 'g',
                        border: const OutlineInputBorder(),
                      ),
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                      validator: _validateOptionalNumber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sugar,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.sugarOptionalLabel,
                        suffixText: 'g',
                        border: const OutlineInputBorder(),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                      validator: _validateOptionalNumber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l10n.servingsSectionTitle, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final (index, row) in _servings.indexed) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        key: Key('serving-name-$index'),
                        controller: row.name,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 40,
                        decoration: InputDecoration(
                          labelText: l10n.servingNameLabel,
                          hintText: l10n.servingNameHint,
                          counterText: '',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => _validateServingName(row, v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        key: Key('serving-grams-$index'),
                        controller: row.grams,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.servingGramsLabel,
                          suffixText: 'g',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => _validateServingGrams(row, v),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.removeServingTooltip,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _removeServing(row),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (_servings.length < _maxServings)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addServing,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.addServingButton),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
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
                    : Text(
                        _isEditing ? l10n.saveChangesButton : l10n.saveButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One editable serving in the form (LIF-146): a name and an amount in grams.
class _ServingRow {
  _ServingRow(String name, String grams)
      : name = TextEditingController(text: name),
        grams = TextEditingController(text: grams);

  final TextEditingController name;
  final TextEditingController grams;

  void addListener(VoidCallback listener) {
    name.addListener(listener);
    grams.addListener(listener);
  }

  void dispose() {
    name.dispose();
    grams.dispose();
  }
}
