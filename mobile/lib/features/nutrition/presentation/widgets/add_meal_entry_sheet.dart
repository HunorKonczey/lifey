import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/search_normalize.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/food_controller.dart';
import '../../application/food_usage_provider.dart';
import '../../application/remaining_budget_provider.dart';
import '../../domain/food.dart';
import '../../domain/food_usage.dart';
import '../../domain/remaining_budget.dart';

/// Result of picking a food + quantity for a meal entry.
typedef MealEntryDraft = ({Food food, double grams});

/// Bottom sheet to pick a food and enter grams. Pops with a [MealEntryDraft].
///
/// Pass [initialFood] and [initialGrams] to open in edit mode — the food field
/// is pre-filled and locked to the existing food, only the quantity is editable.
///
/// Pass [mealDateTime] so the sheet can show a live "what this does to
/// today's budget" preview under the quantity field — only rendered when the
/// meal being built/edited is dated today and a calorie goal is set.
class AddMealEntrySheet extends ConsumerStatefulWidget {
  const AddMealEntrySheet({
    super.key,
    this.initialFood,
    this.initialGrams,
    this.mealDateTime,
  });

  final Food? initialFood;
  final double? initialGrams;
  final DateTime? mealDateTime;

  @override
  ConsumerState<AddMealEntrySheet> createState() => _AddMealEntrySheetState();
}

/// Cap on how many matching foods are shown at once, so the suggestion list
/// stays short even as the food catalog grows.
const _maxSuggestions = 20;

class _AddMealEntrySheetState extends ConsumerState<AddMealEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _grams;
  final _gramsFocus = FocusNode();
  Food? _food;
  String? _foodError;

  /// The Autocomplete field's controller, captured from its
  /// `fieldViewBuilder` so recent-chip taps can write the food name into it.
  TextEditingController? _foodFieldController;

  /// True while the grams field holds a value we prefilled (the food's
  /// last-used quantity) rather than something the user typed — a later
  /// chip tap may overwrite a prefill, never a hand-entered value.
  bool _gramsAutoFilled = false;

  bool get _isEditing => widget.initialFood != null;

  bool get _isMealToday {
    final mealDateTime = widget.mealDateTime;
    return mealDateTime != null && DateUtils.isSameDay(mealDateTime, DateTime.now());
  }

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
    _gramsFocus.dispose();
    super.dispose();
  }

  void _prefillGrams(FoodUsage stats) {
    if (_grams.text.trim().isNotEmpty && !_gramsAutoFilled) return;
    final text = stats.lastGrams.toStringAsFixed(0);
    _grams.text = text;
    // Select the prefill so typing replaces it outright.
    _grams.selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    _gramsAutoFilled = true;
  }

  void _pickRecent(Food food, FoodUsage stats) {
    _foodFieldController?.text = food.name;
    setState(() {
      _food = food;
      _foodError = null;
    });
    _prefillGrams(stats);
    _gramsFocus.requestFocus();
  }

  /// Live "+320 kcal · 28 g protein" line under the grams field, with an
  /// optional "→ 420 kcal left" outcome appended when [mealDateTime] is today
  /// and a calorie goal is set. In edit mode, subtracts the entry's original
  /// contribution first so the outcome reflects the *change*, not a
  /// double-count of an entry already folded into [budget].
  Widget? _buildImpactPreview(BuildContext context, RemainingBudget? budget) {
    final food = _food;
    if (food == null || food.caloriesPer100g <= 0) return null;
    final grams = double.tryParse(_grams.text.replaceAll(',', '.'));
    if (grams == null || grams <= 0) return null;

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final mc = context.metricColors;

    final newKcal = food.caloriesPer100g * grams / 100;
    final newProtein = food.proteinPer100g * grams / 100;

    final children = <Widget>[
      Text(
        l10n.mealEntryImpactPreview(newKcal.round(), newProtein.round()),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];

    if (_isMealToday && budget != null && budget.calories.hasGoal) {
      final oldKcal = widget.initialFood != null
          ? widget.initialFood!.caloriesPer100g * (widget.initialGrams ?? 0) / 100
          : 0.0;
      final remainingAfter = budget.calories.remaining! - (newKcal - oldKcal);
      final over = remainingAfter < 0;
      children.add(Text(
        over
            ? l10n.mealEntryBudgetOver(remainingAfter.abs().round())
            : l10n.mealEntryBudgetLeft(remainingAfter.round()),
        style: theme.textTheme.labelMedium?.copyWith(
          color: over ? mc.negative : mc.calories,
          fontWeight: FontWeight.w700,
        ),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
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
    final usage = ref.watch(foodUsageProvider).value ?? const <String, FoodUsage>{};
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
          final ranked = rankFoodsByUsage(foods, usage);
          final recents = _isEditing ? const <Food>[] : recentFoodsByUsage(foods, usage);
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
                if (recents.isNotEmpty) ...[
                  _RecentFoodsRow(
                    label: l10n.recentFoodsLabel,
                    recents: recents,
                    onPick: (food) => _pickRecent(food, usage[food.clientId]!),
                  ),
                  const SizedBox(height: 12),
                ],
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
                          ? ranked
                          : ranked.where((f) => normalizeForSearch(f.name).contains(query));
                      return matches.take(_maxSuggestions);
                    },
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                      _foodFieldController = controller;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: true,
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
                    onSelected: (food) {
                      setState(() {
                        _food = food;
                        _foodError = null;
                      });
                      final stats = usage[food.clientId];
                      if (stats != null) _prefillGrams(stats);
                      _gramsFocus.requestFocus();
                    },
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _grams,
                  focusNode: _gramsFocus,
                  autofocus: _isEditing,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.quantityLabel,
                    suffixText: 'g',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _gramsAutoFilled = false,
                  validator: (v) {
                    final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (parsed == null) return l10n.enterANumberError;
                    if (parsed <= 0) return l10n.mustBeGreaterThanZeroError;
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _grams,
                  builder: (context, _, __) {
                    // Only watch the budget provider (and its settings/meal
                    // dependencies) when it could actually matter — keeps the
                    // sheet cheap to open for a past-dated meal, and avoids
                    // depending on repositories the sheet doesn't otherwise
                    // need when logging for a non-today date.
                    final budget = _isMealToday
                        ? ref.watch(remainingBudgetProvider).value
                        : null;
                    final preview = _buildImpactPreview(context, budget);
                    if (preview == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: preview,
                    );
                  },
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

// ---------------------------------------------------------------------------
// Recent foods quick-pick row
// ---------------------------------------------------------------------------

class _RecentFoodsRow extends StatelessWidget {
  const _RecentFoodsRow({
    required this.label,
    required this.recents,
    required this.onPick,
  });

  final String label;
  final List<Food> recents;
  final ValueChanged<Food> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _RecentFoodChip(
              food: recents[i],
              onTap: () => onPick(recents[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentFoodChip extends StatelessWidget {
  const _RecentFoodChip({required this.food, required this.onTap});

  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          food.name,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
