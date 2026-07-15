import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../nutrition/application/meal_controller.dart';
import '../../../nutrition/data/meal_repository.dart';
import '../../../nutrition/domain/meal.dart';
import '../../domain/recipe.dart';

/// Bottom sheet to log a whole recipe as a meal: pick the meal type and time,
/// and its ingredients become the meal's entries. The per-portion amount of
/// each ingredient can be adjusted before logging (0 leaves it out), so a
/// serving that deviated from the recipe is logged as actually eaten.
/// Pops on success.
class LogRecipeSheet extends ConsumerStatefulWidget {
  const LogRecipeSheet({super.key, required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<LogRecipeSheet> createState() => _LogRecipeSheetState();
}

class _LogRecipeSheetState extends ConsumerState<LogRecipeSheet> {
  static final _label = DateFormat('EEE, MMM d · HH:mm');

  static const _minPortionDivisor = 1;
  static const _maxPortionDivisor = 20;

  late MealType _mealType = _defaultForNow();
  DateTime _dateTime = DateTime.now();
  bool _submitting = false;
  late bool _isPartialLog;
  late int _portionDivisor;

  bool _showIngredients = false;

  /// Per-ingredient (by index) grams the user typed in, replacing the
  /// divisor-derived default. Kept when the divisor changes — an explicit
  /// "this is what I ate" beats a recalculated default.
  final Map<int, double> _overrides = {};
  late final List<TextEditingController> _gramsControllers;

  @override
  void initState() {
    super.initState();
    // Prefill the divider with the recipe's saved serving count, so the sheet
    // opens already split into the portions the recipe was created to yield.
    final servings = widget.recipe.servings.clamp(_minPortionDivisor, _maxPortionDivisor);
    _portionDivisor = servings;
    _isPartialLog = servings > 1;
    _gramsControllers = [
      for (var i = 0; i < widget.recipe.ingredients.length; i++)
        TextEditingController(text: _fmtGrams(_defaultGramsFor(i))),
    ];
  }

  @override
  void dispose() {
    for (final controller in _gramsControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  static MealType _defaultForNow() {
    final hour = DateTime.now().hour;
    if (hour < 11) return MealType.breakfast;
    if (hour < 15) return MealType.lunch;
    if (hour < 21) return MealType.dinner;
    return MealType.snack;
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (!mounted) return;
    final picked = DateTime(date.year, date.month, date.day,
        time?.hour ?? _dateTime.hour, time?.minute ?? _dateTime.minute);
    setState(() => _dateTime = picked);
  }

  void _decrementPortionDivisor() {
    if (_portionDivisor <= _minPortionDivisor) return;
    setState(() {
      _portionDivisor--;
      _syncDefaultControllers();
    });
  }

  void _incrementPortionDivisor() {
    if (_portionDivisor >= _maxPortionDivisor) return;
    setState(() {
      _portionDivisor++;
      _syncDefaultControllers();
    });
  }

  double _effectiveGrams(double grams) {
    if (!_isPartialLog) return grams;
    return (grams / _portionDivisor * 100).round() / 100;
  }

  double _defaultGramsFor(int index) =>
      _effectiveGrams(widget.recipe.ingredients[index].quantityInGrams);

  /// Grams actually being logged for one ingredient: the user's override if
  /// there is one, otherwise the divisor-derived default.
  double _gramsFor(int index) => _overrides[index] ?? _defaultGramsFor(index);

  /// Rewrites the text of every non-overridden field after the divisor or the
  /// part-meal toggle changed; overridden fields keep the user's value.
  void _syncDefaultControllers() {
    for (var i = 0; i < _gramsControllers.length; i++) {
      if (_overrides.containsKey(i)) continue;
      _gramsControllers[i].text = _fmtGrams(_defaultGramsFor(i));
    }
  }

  void _onGramsChanged(int index, String text) {
    final parsed = double.tryParse(text.replaceAll(',', '.').trim());
    if (parsed == null || parsed < 0) return; // keep last valid value
    setState(() => _overrides[index] = parsed);
  }

  void _resetOverride(int index) {
    setState(() {
      _overrides.remove(index);
      _gramsControllers[index].text = _fmtGrams(_defaultGramsFor(index));
    });
  }

  static String _fmtGrams(double grams) {
    final rounded = (grams * 100).round() / 100;
    if (rounded == rounded.roundToDouble()) return rounded.round().toString();
    return rounded.toString();
  }

  /// Effective total of one macro across all ingredients, each scaled to the
  /// grams actually being logged (overrides included).
  double _scaledTotal(double Function(RecipeIngredient) macroOf) {
    var sum = 0.0;
    final ingredients = widget.recipe.ingredients;
    for (var i = 0; i < ingredients.length; i++) {
      final ingredient = ingredients[i];
      if (ingredient.quantityInGrams <= 0) continue;
      sum += macroOf(ingredient) * _gramsFor(i) / ingredient.quantityInGrams;
    }
    return sum;
  }

  bool get _hasLoggableEntry {
    for (var i = 0; i < widget.recipe.ingredients.length; i++) {
      if (_gramsFor(i) > 0) return true;
    }
    return false;
  }

  Future<void> _submit() async {
    if (_submitting) return; // guard against a fast double-tap creating two meals
    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      final ingredients = widget.recipe.ingredients;
      await ref.read(mealControllerProvider.notifier).logMeal(
            dateTime: _dateTime,
            mealType: _mealType,
            name: widget.recipe.name,
            entries: [
              for (var i = 0; i < ingredients.length; i++)
                if (_gramsFor(i) > 0)
                  MealEntryInput(
                      foodClientId: ingredients[i].foodClientId,
                      grams: _gramsFor(i)),
            ],
          );
      navigator.pop();
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          title: l10n.loggedRecipeAsMessage(
              widget.recipe.name, _mealType.label(l10n).toLowerCase()),
        );
      }
    } catch (_) {
      setState(() => _submitting = false);
      if (mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotLogMealMessage);
      }
    }
  }

  Widget _ingredientRow(int index, AppLocalizations l10n) {
    final ingredient = widget.recipe.ingredients[index];
    final overridden = _overrides.containsKey(index);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ingredient.foodName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (overridden)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: l10n.resetIngredientTooltip,
              onPressed: _submitting ? null : () => _resetOverride(index),
              icon: const Icon(Icons.restart_alt, size: 20),
            ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: TextField(
              controller: _gramsControllers[index],
              enabled: !_submitting,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              textAlign: TextAlign.end,
              decoration: const InputDecoration(
                isDense: true,
                suffixText: 'g',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (text) => _onGramsChanged(index, text),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final count = widget.recipe.ingredients.length;
    final l10n = AppLocalizations.of(context)!;
    // A recipe without ingredients logs an empty meal, as before; with
    // ingredients, at least one non-zero amount is required.
    final canSubmit = !_submitting && (count == 0 || _hasLoggableEntry);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.logRecipeTitle(widget.recipe.name),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l10n.ingredientsToMealEntriesLabel(count),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Text(l10n.mealTypeLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: MealType.values.map((type) {
                return ChoiceChip(
                  label: Text(type.label(l10n)),
                  selected: _mealType == type,
                  onSelected: (_) => setState(() => _mealType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(l10n.whenLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _pickDateTime,
              icon: const Icon(Icons.schedule),
              label: Text(_label.format(_dateTime)),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.logAsPartMealButton),
              value: _isPartialLog,
              onChanged: _submitting
                  ? null
                  : (value) => setState(() {
                        _isPartialLog = value;
                        _syncDefaultControllers();
                      }),
            ),
            if (_isPartialLog) ...[
              const SizedBox(height: 8),
              Text(l10n.divideIntoPartsLabel,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: _submitting ? null : _decrementPortionDivisor,
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('$_portionDivisor',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: _submitting ? null : _incrementPortionDivisor,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
            if (count > 0) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _showIngredients = !_showIngredients),
                  icon: Icon(_showIngredients ? Icons.expand_less : Icons.tune),
                  label: Text(l10n.adjustIngredientsButton),
                ),
              ),
              if (_showIngredients) ...[
                Text(l10n.ingredientAmountsHint,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                for (var i = 0; i < count; i++) _ingredientRow(i, l10n),
              ],
            ],
            const SizedBox(height: 8),
            Text(
              l10n.recipeMacrosPreviewLabel(
                _scaledTotal((i) => i.calories).round().toString(),
                _scaledTotal((i) => i.protein).toStringAsFixed(1),
                _scaledTotal((i) => i.carbs).toStringAsFixed(1),
                _scaledTotal((i) => i.fat).toStringAsFixed(1),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: canSubmit ? _submit : null,
              icon: _submitting
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.restaurant),
              label: Text(l10n.logMealButton),
            ),
          ],
        ),
      ),
    );
  }
}
