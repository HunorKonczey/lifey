import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/search_normalize.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/food_controller.dart';
import '../../domain/food.dart';

/// Result of picking a food + quantity for a meal entry.
typedef MealEntryDraft = ({Food food, double grams});

/// Bottom sheet to pick a food and enter grams. Pops with a [MealEntryDraft].
///
/// Pass [initialFood] and [initialGrams] to open in edit mode — the food field
/// is pre-filled and locked to the existing food, only the quantity is editable.
class AddMealEntrySheet extends ConsumerStatefulWidget {
  const AddMealEntrySheet({super.key, this.initialFood, this.initialGrams});

  final Food? initialFood;
  final double? initialGrams;

  @override
  ConsumerState<AddMealEntrySheet> createState() => _AddMealEntrySheetState();
}

/// Cap on how many matching foods are shown at once, so the suggestion list
/// stays short even as the food catalog grows.
const _maxSuggestions = 20;

class _AddMealEntrySheetState extends ConsumerState<AddMealEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _grams;
  Food? _food;
  String? _foodError;

  bool get _isEditing => widget.initialFood != null;

  @override
  void initState() {
    super.initState();
    _food = widget.initialFood;
    final initial = widget.initialGrams?.toStringAsFixed(0) ?? '';
    _grams = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    final foodPicked = _food != null;
    setState(() => _foodError = foodPicked ? null : AppLocalizations.of(context)!.pickAFoodError);
    if (!formValid || !foodPicked) return;
    final grams = double.parse(_grams.text.replaceAll(',', '.'));
    Navigator.of(context).pop<MealEntryDraft>((food: _food!, grams: grams));
  }

  @override
  Widget build(BuildContext context) {
    final foodsState = ref.watch(foodSearchProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: foodsState.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('${l10n.couldNotLoadFoodsPrefix} $e'),
        ),
        data: (foods) {
          if (foods.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.addFoodsFirstMessage),
            );
          }
          return Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing ? l10n.editFoodEntryTitle : l10n.addFoodToMealTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (_isEditing)
                  TextFormField(
                    initialValue: widget.initialFood!.name,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: l10n.foodFieldLabel,
                      border: const OutlineInputBorder(),
                    ),
                  )
                else
                  Autocomplete<Food>(
                    displayStringForOption: (f) => f.name,
                    optionsBuilder: (textEditingValue) {
                      final query = normalizeForSearch(textEditingValue.text.trim());
                      final matches = query.isEmpty
                          ? foods
                          : foods.where((f) => normalizeForSearch(f.name).contains(query));
                      return matches.take(_maxSuggestions);
                    },
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: l10n.foodFieldLabel,
                          border: const OutlineInputBorder(),
                          errorText: _foodError,
                          suffixIcon: _food == null
                              ? const Icon(Icons.search)
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    controller.clear();
                                    setState(() => _food = null);
                                  },
                                ),
                        ),
                        onChanged: (_) {
                          if (_food != null) setState(() => _food = null);
                        },
                      );
                    },
                    onSelected: (food) => setState(() {
                      _food = food;
                      _foodError = null;
                    }),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _grams,
                  autofocus: _isEditing,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.quantityLabel,
                    suffixText: 'g',
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
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submit,
                  child: Text(_isEditing ? l10n.saveButton : l10n.addButton),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
