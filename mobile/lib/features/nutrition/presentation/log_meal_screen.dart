import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/meal_controller.dart';
import '../data/meal_repository.dart';
import '../domain/food.dart';
import '../domain/meal.dart';
import 'widgets/add_meal_entry_sheet.dart';

/// Full-screen form for logging a meal, or editing one when [meal] is provided.
class LogMealScreen extends ConsumerStatefulWidget {
  const LogMealScreen({super.key, this.meal});

  final Meal? meal;

  @override
  ConsumerState<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends ConsumerState<LogMealScreen> {
  static final _dateTimeLabel = DateFormat('EEE, MMM d · HH:mm');

  late MealType _mealType;
  late DateTime _dateTime;
  final List<({Food food, double grams})> _entries = [];
  bool _saving = false;

  bool get _isEditing => widget.meal != null;

  @override
  void initState() {
    super.initState();
    final meal = widget.meal;
    _mealType = meal?.mealType ?? MealType.breakfast;
    _dateTime = meal?.dateTime ?? DateTime.now();
    if (meal != null) {
      for (final entry in meal.entries) {
        // Only id + name are needed downstream; macros aren't sent on save.
        _entries.add((
          food: Food(
            id: entry.foodId,
            name: entry.foodName,
            caloriesPer100g: 0,
            proteinPer100g: 0,
          ),
          grams: entry.quantityInGrams,
        ));
      }
    }
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
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? _dateTime.hour,
      time?.minute ?? _dateTime.minute,
    );
    // Keep it past-or-present to satisfy the backend.
    setState(() => _dateTime = picked.isAfter(now) ? now : picked);
  }

  Future<void> _addEntry() async {
    final draft = await showModalBottomSheet<MealEntryDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddMealEntrySheet(),
    );
    if (draft != null) {
      setState(() => _entries.add((food: draft.food, grams: draft.grams)));
    }
  }

  Future<void> _save() async {
    if (_saving) return; // guard against a fast double-tap creating two meals
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one food')),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final entries = _entries
        .map((e) => MealEntryInput(foodId: e.food.id, grams: e.grams))
        .toList();
    try {
      final notifier = ref.read(mealControllerProvider.notifier);
      if (_isEditing) {
        await notifier.updateMeal(widget.meal!.id,
            dateTime: _dateTime, mealType: _mealType, entries: entries);
      } else {
        await notifier.logMeal(
            dateTime: _dateTime, mealType: _mealType, entries: entries);
      }
      navigator.pop();
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
            content: Text("Couldn't save the meal. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit meal' : 'Log meal'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          const SizedBox(height: 20),
          Text('When', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickDateTime,
            icon: const Icon(Icons.schedule),
            label: Text(_dateTimeLabel.format(_dateTime)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Foods', style: Theme.of(context).textTheme.labelLarge),
              TextButton.icon(
                onPressed: _addEntry,
                icon: const Icon(Icons.add),
                label: const Text('Add food'),
              ),
            ],
          ),
          if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No foods added yet'),
            )
          else
            ..._entries.asMap().entries.map((e) {
              final draft = e.value;
              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  title: Text(draft.food.name),
                  subtitle: Text('${draft.grams.toStringAsFixed(0)} g'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _entries.removeAt(e.key)),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
