import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../domain/recipe_wizard.dart';

/// The five-step wizard (docs/23-ai-calorie-estimation-plan.md Phase 2): one
/// question per step, back navigation, and a progress bar. Entirely local —
/// it pops with the collected [RecipeWizardAnswers] and the caller does the
/// one network call.
///
/// The meat step is skipped for a vegetarian or vegan diet, in both
/// directions, so stepping back from "extras" doesn't land on a question that
/// no longer applies.
class RecipeWizardSheet extends StatefulWidget {
  const RecipeWizardSheet({super.key});

  @override
  State<RecipeWizardSheet> createState() => _RecipeWizardSheetState();
}

class _RecipeWizardSheetState extends State<RecipeWizardSheet> {
  static const _diet = 0;
  static const _meal = 1;
  static const _calories = 2;
  static const _meat = 3;
  static const _extras = 4;
  static const _stepCount = 5;

  final _extraRequest = TextEditingController();
  RecipeWizardAnswers _answers = const RecipeWizardAnswers();
  int _step = _diet;

  @override
  void dispose() {
    _extraRequest.dispose();
    super.dispose();
  }

  bool get _skipsMeat => _answers.dietType != null && !_answers.dietType!.allowsMeat;

  void _goTo(int step) {
    if (step > _extras) return;
    if (step == _meat && _skipsMeat) {
      setState(() => _step = _extras);
      return;
    }
    setState(() => _step = step);
  }

  void _back() {
    if (_step == _diet) {
      Navigator.of(context).pop();
      return;
    }
    final previous = _step == _extras && _skipsMeat ? _calories : _step - 1;
    setState(() => _step = previous);
  }

  void _answer(RecipeWizardAnswers answers) {
    setState(() => _answers = answers);
    _goTo(_step + 1);
  }

  void _generate() {
    Navigator.of(context).pop(_answers.copyWith(extraRequest: _extraRequest.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(_step == _diet ? Icons.close : Icons.arrow_back),
                onPressed: _back,
                tooltip: _step == _diet ? l10n.cancelButton : l10n.recipeWizardBackTooltip,
              ),
              Expanded(
                child: Text(_title(l10n), style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (_step + 1) / _stepCount,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 16),
          _stepBody(l10n),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _title(AppLocalizations l10n) => switch (_step) {
        _diet => l10n.recipeWizardDietTitle,
        _meal => l10n.recipeWizardMealTitle,
        _calories => l10n.recipeWizardCaloriesTitle,
        _meat => l10n.recipeWizardMeatTitle,
        _ => l10n.recipeWizardExtrasTitle,
      };

  Widget _stepBody(AppLocalizations l10n) {
    return switch (_step) {
      _diet => _Choices(
          labels: {
            RecipeDietType.anything: l10n.recipeDietAnything,
            RecipeDietType.meat: l10n.recipeDietMeat,
            RecipeDietType.fish: l10n.recipeDietFish,
            RecipeDietType.vegetarian: l10n.recipeDietVegetarian,
            RecipeDietType.vegan: l10n.recipeDietVegan,
          },
          selected: _answers.dietType,
          onSelected: (value) => _answer(_answers.copyWith(dietType: value)),
        ),
      _meal => _Choices(
          labels: {
            RecipeMealType.breakfast: l10n.mealTypeBreakfast,
            RecipeMealType.lunch: l10n.mealTypeLunch,
            RecipeMealType.dinner: l10n.mealTypeDinner,
            RecipeMealType.snack: l10n.mealTypeSnack,
          },
          selected: _answers.mealType,
          onSelected: (value) => _answer(_answers.copyWith(mealType: value)),
        ),
      _calories => _Choices(
          labels: {
            RecipeCalorieBand.under300: l10n.recipeCaloriesUnder300,
            RecipeCalorieBand.from300To500: l10n.recipeCalories300To500,
            RecipeCalorieBand.from500To700: l10n.recipeCalories500To700,
            RecipeCalorieBand.over700: l10n.recipeCaloriesOver700,
          },
          selected: _answers.calorieBand,
          onSelected: (value) => _answer(_answers.copyWith(calorieBand: value)),
        ),
      _meat => _Choices(
          labels: {
            RecipeMeatType.chicken: l10n.recipeMeatChicken,
            RecipeMeatType.beef: l10n.recipeMeatBeef,
            RecipeMeatType.pork: l10n.recipeMeatPork,
            RecipeMeatType.turkey: l10n.recipeMeatTurkey,
            RecipeMeatType.fish: l10n.recipeMeatFish,
            RecipeMeatType.any: l10n.recipeMeatSurpriseMe,
          },
          selected: _answers.meatType,
          onSelected: (value) => _answer(_answers.copyWith(meatType: value)),
        ),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _extraRequest,
              autofocus: true,
              maxLength: 500,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.recipeWizardExtrasHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _answers.isComplete ? _generate : null,
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: Text(l10n.recipeWizardGenerateButton),
            ),
          ],
        ),
    };
  }
}

/// One question's answers as chips, in a wrap so long labels don't clip.
class _Choices<T> extends StatelessWidget {
  const _Choices({required this.labels, required this.selected, required this.onSelected});

  final Map<T, String> labels;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in labels.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: selected == entry.key,
            onSelected: (_) => onSelected(entry.key),
          ),
      ],
    );
  }
}
