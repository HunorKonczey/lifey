import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/meal_controller.dart';
import '../data/meal_repository.dart';
import '../domain/food.dart';
import '../domain/meal.dart';
import 'widgets/add_meal_entry_sheet.dart';

/// Full-screen form for logging a meal: type, time, and food entries.
class LogMealScreen extends ConsumerStatefulWidget {
  const LogMealScreen({super.key});

  @override
  ConsumerState<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends ConsumerState<LogMealScreen> {
  static final _dateTimeLabel = DateFormat('EEE, MMM d · HH:mm');

  MealType _mealType = MealType.breakfast;
  DateTime _dateTime = DateTime.now();
  final List<({Food food, double grams})> _entries = [];
  bool _saving = false;

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
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one food')),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(mealControllerProvider.notifier).logMeal(
            dateTime: _dateTime,
            mealType: _mealType,
            entries: _entries
                .map((e) => MealEntryInput(foodId: e.food.id, grams: e.grams))
                .toList(),
          );
      navigator.pop();
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't log the meal. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log meal'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
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
