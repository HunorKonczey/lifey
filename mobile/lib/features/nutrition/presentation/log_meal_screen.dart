import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
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
        // Only clientId + name are needed downstream; macros aren't sent on save.
        _entries.add((
          food: Food(
            clientId: entry.foodClientId,
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
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddMealEntrySheet(),
    );
    if (draft != null) {
      setState(() => _entries.add((food: draft.food, grams: draft.grams)));
    }
  }

  Future<void> _editEntry(int index) async {
    final current = _entries[index];
    final draft = await showModalBottomSheet<MealEntryDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddMealEntrySheet(
        initialFood: current.food,
        initialGrams: current.grams,
      ),
    );
    if (draft != null) {
      setState(() => _entries[index] = (food: draft.food, grams: draft.grams));
    }
  }

  Future<void> _save() async {
    if (_saving) return; // guard against a fast double-tap creating two meals
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.addAtLeastOneFoodMessage)),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final couldNotSaveMealMessage = AppLocalizations.of(context)!.couldNotSaveMealMessage;
    final entries = _entries
        .map((e) => MealEntryInput(foodClientId: e.food.clientId, grams: e.grams))
        .toList();
    try {
      final notifier = ref.read(mealControllerProvider.notifier);
      if (_isEditing) {
        await notifier.updateMeal(widget.meal!.clientId,
            dateTime: _dateTime, mealType: _mealType, entries: entries);
      } else {
        await notifier.logMeal(
            dateTime: _dateTime, mealType: _mealType, entries: entries);
      }
      navigator.pop();
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(couldNotSaveMealMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(_isEditing ? l10n.editMealTitle : l10n.logMealTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.saveButton),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          const SizedBox(height: 20),
          Text(l10n.whenLabel, style: Theme.of(context).textTheme.labelLarge),
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
              Text(l10n.foodsLabel, style: Theme.of(context).textTheme.labelLarge),
              TextButton.icon(
                onPressed: _addEntry,
                icon: const Icon(Icons.add),
                label: Text(l10n.addFoodButton),
              ),
            ],
          ),
          if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l10n.noFoodsAddedYetMessage),
            )
          else
            ..._entries.asMap().entries.map((e) {
              final draft = e.value;
              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  title: Text(draft.food.name),
                  subtitle: Text(l10n.gramsValue(draft.grams.toStringAsFixed(0))),
                  onTap: () => _editEntry(e.key),
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
