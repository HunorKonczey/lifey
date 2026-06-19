import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/food_controller.dart';
import '../../domain/food.dart';

/// Bottom sheet form to create a food, or edit one when [food] is provided.
/// Pops on success.
class AddFoodSheet extends ConsumerStatefulWidget {
  const AddFoodSheet({super.key, this.food});

  final Food? food;

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
  String? _error;

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
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
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
    final parsed = _parse(value ?? '');
    if (parsed == null) return 'Enter a number';
    if (parsed < 0) return 'Must be 0 or more';
    return null;
  }

  String? _validateOptionalNumber(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    final parsed = _parse(value!);
    if (parsed == null) return 'Enter a number';
    if (parsed < 0) return 'Must be 0 or more';
    return null;
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
        await notifier.updateFood(widget.food!.id,
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat);
      } else {
        await notifier.addFood(
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      final isDuplicate = e is DioException && e.response?.statusCode == 409;
      setState(() => _error = isDuplicate
          ? 'A food named "$name" already exists.'
          : "Couldn't save the food. Please try again.");
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
            Text(_isEditing ? 'Edit food' : 'Add food',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Values are per 100 g',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _calories,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Calories',
                      suffixText: 'kcal',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateRequiredNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _protein,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Protein',
                      suffixText: 'g',
                      border: OutlineInputBorder(),
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Carbs (optional)',
                      suffixText: 'g',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateOptionalNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _fat,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Fat (optional)',
                      suffixText: 'g',
                      border: OutlineInputBorder(),
                    ),
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
                  : Text(_isEditing ? 'Save changes' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
