import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../nutrition/application/meal_controller.dart';
import '../../../nutrition/data/meal_repository.dart';
import '../../../nutrition/domain/meal.dart';
import '../../domain/recipe.dart';

/// Bottom sheet to log a whole recipe as a meal: pick the meal type and time,
/// and its ingredients become the meal's entries. Pops on success.
class LogRecipeSheet extends ConsumerStatefulWidget {
  const LogRecipeSheet({super.key, required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<LogRecipeSheet> createState() => _LogRecipeSheetState();
}

class _LogRecipeSheetState extends ConsumerState<LogRecipeSheet> {
  static final _label = DateFormat('EEE, MMM d · HH:mm');

  late MealType _mealType = _defaultForNow();
  DateTime _dateTime = DateTime.now();
  bool _submitting = false;

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
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (!mounted) return;
    final picked = DateTime(date.year, date.month, date.day,
        time?.hour ?? _dateTime.hour, time?.minute ?? _dateTime.minute);
    setState(() => _dateTime = picked.isAfter(now) ? now : picked);
  }

  Future<void> _submit() async {
    if (_submitting) return; // guard against a fast double-tap creating two meals
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(mealControllerProvider.notifier).logMeal(
            dateTime: _dateTime,
            mealType: _mealType,
            entries: widget.recipe.ingredients
                .map((i) => MealEntryInput(
                    foodClientId: i.foodClientId, grams: i.quantityInGrams))
                .toList(),
          );
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Logged "${widget.recipe.name}" as ${_mealType.label.toLowerCase()}'),
      ));
    } catch (_) {
      setState(() => _submitting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't log the meal. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final count = widget.recipe.ingredients.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Log "${widget.recipe.name}"',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('$count ${count == 1 ? 'ingredient' : 'ingredients'} → meal entries',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Text('Meal type', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: MealType.values.map((type) {
              return ChoiceChip(
                label: Text(type.label),
                selected: _mealType == type,
                onSelected: (_) => setState(() => _mealType = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('When', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickDateTime,
            icon: const Icon(Icons.schedule),
            label: Text(_label.format(_dateTime)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.restaurant),
            label: const Text('Log meal'),
          ),
        ],
      ),
    );
  }
}
