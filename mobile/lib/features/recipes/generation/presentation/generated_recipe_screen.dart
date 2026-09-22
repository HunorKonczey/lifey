import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/entitlements/paywall_navigation.dart';
import '../../../../core/entitlements/paywall_trigger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../application/generated_recipe_saver.dart';
import '../application/recipe_generation_controller.dart';
import '../domain/generated_recipe.dart';
import '../domain/recipe_wizard.dart';

/// Runs the generation for [answers] and shows the proposal
/// (docs/23-ai-calorie-estimation-plan.md Phase 2): name and servings are
/// editable, each ingredient shows whether it is already in the user's foods
/// or would be added, quantities can be changed and ingredients removed.
///
/// Saving writes a normal, local-first recipe; the generation was the only
/// online step. "Try again" re-runs the same answers — and spends another
/// credit, which is why it is a secondary action.
class GeneratedRecipeScreen extends ConsumerStatefulWidget {
  const GeneratedRecipeScreen({super.key, required this.answers});

  final RecipeWizardAnswers answers;

  @override
  ConsumerState<GeneratedRecipeScreen> createState() => _GeneratedRecipeScreenState();
}

class _GeneratedRecipeScreenState extends ConsumerState<GeneratedRecipeScreen> {
  final _name = TextEditingController();
  final _quantities = <int, TextEditingController>{};
  final _removed = <int>{};
  int _servings = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  @override
  void dispose() {
    _name.dispose();
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _generate() {
    ref.read(recipeGenerationControllerProvider.notifier).generate(widget.answers);
  }

  void _adopt(GeneratedRecipe recipe) {
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    _quantities.clear();
    _removed.clear();
    _name.text = recipe.name;
    _servings = recipe.servings;
    for (var index = 0; index < recipe.ingredients.length; index++) {
      _quantities[index] = TextEditingController(
          text: _formatGrams(recipe.ingredients[index].quantityInGrams));
    }
    setState(() {});
  }

  Future<void> _save(GeneratedRecipe recipe) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    if (_name.text.trim().isEmpty || _keptCount(recipe) == 0) return;
    setState(() => _saving = true);
    try {
      final saved = await ref.read(generatedRecipeSaverProvider).save(
            recipe,
            name: _name.text.trim(),
            servings: _servings,
            quantities: {
              for (var index = 0; index < recipe.ingredients.length; index++)
                index: _removed.contains(index)
                    ? null
                    : double.tryParse(_quantities[index]!.text.replaceAll(',', '.').trim()),
            },
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackbar.showSuccess(
        context,
        title: saved.skippedIngredients == 0
            ? l10n.generatedRecipeSavedMessage
            : l10n.generatedRecipeSavedWithSkippedMessage(saved.skippedIngredients),
      );
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotSaveRecipeMessage);
        setState(() => _saving = false);
      }
    }
  }

  int _keptCount(GeneratedRecipe recipe) {
    var kept = 0;
    for (var index = 0; index < recipe.ingredients.length; index++) {
      if (_removed.contains(index)) continue;
      final grams = double.tryParse(_quantities[index]!.text.replaceAll(',', '.').trim());
      if (grams != null && grams > 0) kept++;
    }
    return kept;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(recipeGenerationControllerProvider);

    ref.listen(recipeGenerationControllerProvider, (_, next) {
      if (next is RecipeGenerationDone) {
        _adopt(next.recipe);
      } else if (next is RecipeGenerationCreditsExhausted) {
        Navigator.of(context).pop();
        openPaywall(context, PaywallTrigger.aiCredits);
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.generatedRecipeTitle)),
      body: SafeArea(
        child: switch (state) {
          RecipeGenerationDone(:final recipe) when _quantities.isNotEmpty =>
            _buildProposal(context, recipe),
          RecipeGenerationOffline() => _Status(
              message: l10n.recipeGenerationOfflineMessage, onRetry: _generate),
          RecipeGenerationFailed() => _Status(
              message: l10n.recipeGenerationFailedMessage, onRetry: _generate),
          _ => _Status(message: l10n.recipeGenerationLoadingMessage, loading: true),
        },
      ),
    );
  }

  Widget _buildProposal(BuildContext context, GeneratedRecipe recipe) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final canSave = !_saving && _keptCount(recipe) > 0;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.titleLarge,
                decoration: InputDecoration(
                  labelText: l10n.nameLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _PerServingCard(
                perServing: recipe.perServing,
                servings: _servings,
                onServingsChanged: (value) => setState(() => _servings = value),
                l10n: l10n,
              ),
              const SizedBox(height: 16),
              Text(l10n.ingredientsLabel, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (var index = 0; index < recipe.ingredients.length; index++)
                _IngredientRow(
                  ingredient: recipe.ingredients[index],
                  quantity: _quantities[index]!,
                  removed: _removed.contains(index),
                  onToggleRemoved: () => setState(() {
                    if (!_removed.remove(index)) _removed.add(index);
                  }),
                  onQuantityChanged: () => setState(() {}),
                ),
              if (recipe.description != null && recipe.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.descriptionOptionalLabel, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(recipe.description!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _generate,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: Text(l10n.generatedRecipeRegenerateButton),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: canSave ? () => _save(recipe) : null,
                  child: _saving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.saveButton),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatGrams(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}

class _PerServingCard extends StatelessWidget {
  const _PerServingCard({
    required this.perServing,
    required this.servings,
    required this.onServingsChanged,
    required this.l10n,
  });

  final RecipeMacros perServing;
  final int servings;
  final ValueChanged<int> onServingsChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.servingsLabel, style: theme.textTheme.titleSmall)),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: servings > 1 ? () => onServingsChanged(servings - 1) : null,
              ),
              Text('$servings', style: theme.textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: servings < 12 ? () => onServingsChanged(servings + 1) : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // The figures are the model's proposal for its own serving count —
          // changing the count here rescales what one serving means, so they
          // are labelled as the proposal's, not recomputed live.
          Text(l10n.generatedRecipePerServingLabel, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            '${perServing.calories.round()} kcal · ${l10n.proteinLabel} ${perServing.protein.round()} g'
            ' · ${l10n.carbsLabel} ${perServing.carbs.round()} g'
            ' · ${l10n.fatLabel} ${perServing.fat.round()} g',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.ingredient,
    required this.quantity,
    required this.removed,
    required this.onToggleRemoved,
    required this.onQuantityChanged,
  });

  final GeneratedIngredient ingredient;
  final TextEditingController quantity;
  final bool removed;
  final VoidCallback onToggleRemoved;
  final VoidCallback onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: removed ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ingredient.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      decoration: removed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ingredient.isNew
                        ? l10n.generatedRecipeNewFoodBadge
                        : l10n.generatedRecipeExistingFoodBadge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: ingredient.isNew ? scheme.tertiary : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 92,
              child: TextField(
                controller: quantity,
                enabled: !removed,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.end,
                decoration: const InputDecoration(
                  suffixText: 'g',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => onQuantityChanged(),
              ),
            ),
            IconButton(
              tooltip: removed
                  ? l10n.generatedRecipeRestoreIngredientTooltip
                  : l10n.generatedRecipeRemoveIngredientTooltip,
              icon: Icon(removed ? Icons.undo : Icons.close),
              onPressed: onToggleRemoved,
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading and error states. Nothing here has spent a credit — the server only
/// counts a successful generation — so retrying is free.
class _Status extends StatelessWidget {
  const _Status({required this.message, this.loading = false, this.onRetry});

  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
            ],
            Text(message, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context)!.retryButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
