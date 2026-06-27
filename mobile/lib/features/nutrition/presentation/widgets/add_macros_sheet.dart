import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/food_controller.dart';
import 'add_meal_entry_sheet.dart';

/// Bottom sheet for logging a macro entry directly, without picking a food
/// from the catalog. Creates a hidden food in the background and pops with
/// a [MealEntryDraft] just like [AddMealEntrySheet].
///
/// Calories/protein/carbs/fat are entered as **absolute** values for the
/// serving. If [_grams] is filled in, the per-100g values are back-calculated
/// so the existing meal-entry math (caloriesPer100g × grams / 100) reproduces
/// the entered totals. If [_grams] is left blank, grams defaults to 100 and
/// the entered values are stored directly as per-100g — mathematically
/// identical to adding the macros as-is.
class AddMacrosSheet extends ConsumerStatefulWidget {
  const AddMacrosSheet({super.key});

  @override
  ConsumerState<AddMacrosSheet> createState() => _AddMacrosSheetState();
}

class _AddMacrosSheetState extends ConsumerState<AddMacrosSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _grams = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _grams.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  double? _parse(String text) =>
      double.tryParse(text.replaceAll(',', '.').trim());

  String? _validateRequiredNonNegative(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final parsed = _parse(value ?? '');
    if (parsed == null) return l10n.enterANumberError;
    if (parsed < 0) return l10n.mustBeZeroOrMoreError;
    return null;
  }

  String? _validateOptionalPositive(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    final l10n = AppLocalizations.of(context)!;
    final parsed = _parse(value!);
    if (parsed == null) return l10n.enterANumberError;
    if (parsed <= 0) return l10n.mustBeGreaterThanZeroError;
    return null;
  }

  String? _validateOptionalNonNegative(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    final l10n = AppLocalizations.of(context)!;
    final parsed = _parse(value!);
    if (parsed == null) return l10n.enterANumberError;
    if (parsed < 0) return l10n.mustBeZeroOrMoreError;
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final gramsText = _grams.text.trim();
      final hasGrams = gramsText.isNotEmpty;
      final grams = hasGrams ? _parse(gramsText)! : 100.0;

      final calories = _parse(_calories.text)!;
      final protein = _parse(_protein.text)!;
      final carbs = _carbs.text.trim().isEmpty ? null : _parse(_carbs.text);
      final fat = _fat.text.trim().isEmpty ? null : _parse(_fat.text);

      // Back-calculate per-100g so that: stored × grams / 100 = entered total.
      // When grams is blank we use 100, so factor = 1 and values pass through unchanged.
      final factor = 100.0 / grams;

      final food = await ref.read(foodControllerProvider.notifier).addFood(
            name: _name.text.trim(),
            calories: calories * factor,
            protein: protein * factor,
            carbs: carbs != null ? carbs * factor : null,
            fat: fat != null ? fat * factor : null,
            hidden: true,
          );
      if (mounted) {
        Navigator.of(context).pop<MealEntryDraft>((food: food, grams: grams));
      }
    } catch (_) {
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
            Text(l10n.addMacrosTitle,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            // Name
            TextFormField(
              controller: _name,
              autofocus: true,
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
            // Grams (optional)
            TextFormField(
              controller: _grams,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.quantityLabel,
                suffixText: 'g',
                helperText: l10n.macrosQuantityHelperText,
                border: const OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              validator: _validateOptionalPositive,
            ),
            const SizedBox(height: 12),
            // Calories + Protein
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
                    validator: _validateRequiredNonNegative,
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
                    validator: _validateRequiredNonNegative,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Carbs + Fat (optional)
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
                    validator: _validateOptionalNonNegative,
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
                    validator: _validateOptionalNonNegative,
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
                  : Text(l10n.addButton),
            ),
          ],
        ),
      ),
    );
  }
}
