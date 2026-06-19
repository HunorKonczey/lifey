import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/food_controller.dart';
import '../../domain/food.dart';

/// Result of picking a food + quantity for a meal entry.
typedef MealEntryDraft = ({Food food, double grams});

/// Bottom sheet to pick a food and enter grams. Pops with a [MealEntryDraft].
class AddMealEntrySheet extends ConsumerStatefulWidget {
  const AddMealEntrySheet({super.key});

  @override
  ConsumerState<AddMealEntrySheet> createState() => _AddMealEntrySheetState();
}

/// Cap on how many matching foods are shown at once, so the suggestion list
/// stays short even as the food catalog grows.
const _maxSuggestions = 20;

class _AddMealEntrySheetState extends ConsumerState<AddMealEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _grams = TextEditingController(text: '100');
  Food? _food;
  String? _foodError;

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    final foodPicked = _food != null;
    setState(() => _foodError = foodPicked ? null : 'Pick a food');
    if (!formValid || !foodPicked) return;
    final grams = double.parse(_grams.text.replaceAll(',', '.'));
    Navigator.of(context).pop<MealEntryDraft>((food: _food!, grams: grams));
  }

  @override
  Widget build(BuildContext context) {
    final foodsState = ref.watch(foodControllerProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: foodsState.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Couldn't load foods: $e"),
        ),
        data: (foods) {
          if (foods.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Add some foods first (Foods tab).'),
            );
          }
          return Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Add food to meal',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Autocomplete<Food>(
                  displayStringForOption: (f) => f.name,
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.trim().toLowerCase();
                    final matches = query.isEmpty
                        ? foods
                        : foods.where((f) => f.name.toLowerCase().contains(query));
                    return matches.take(_maxSuggestions);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Food',
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    suffixText: 'g',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (parsed == null) return 'Enter a number';
                    if (parsed <= 0) return 'Must be greater than 0';
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _submit, child: const Text('Add')),
              ],
            ),
          );
        },
      ),
    );
  }
}
