import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/format/parse_decimal.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/search_normalize.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../../recipes/application/recipes_controller.dart';
import '../../../recipes/domain/recipe.dart';
import '../../../recipes/domain/recipe_portion.dart';
import '../../../recipes/presentation/widgets/ingredient_amount_row.dart';
import 'add_meal_entry_sheet.dart';
import 'fiber_sugar_line.dart';

/// What the Add-recipe sheet pops with: the recipe and one entry draft per
/// ingredient with a non-zero amount.
typedef AddRecipeResult = ({Recipe recipe, List<MealEntryDraft> drafts});

/// Bottom sheet to add a recipe to the meal being built (docs/87
/// Prompt M2). Step 1 picks a recipe, step 2 says how much of it was eaten -
/// servings, and optionally the amount of each ingredient - and pops with an
/// [AddRecipeResult]. It never writes a meal itself; the Log meal screen
/// appends the drafts like it does for a food or a photo estimate.
class AddRecipeSheet extends ConsumerStatefulWidget {
  const AddRecipeSheet({super.key});

  @override
  ConsumerState<AddRecipeSheet> createState() => _AddRecipeSheetState();
}

/// What the stepper changes the servings by, and the bounds it keeps them in.
const _servingsStep = 0.5;
const _minServings = 0.25;
const _maxServings = 50.0;

class _AddRecipeSheetState extends ConsumerState<AddRecipeSheet> {
  String _query = '';
  Recipe? _recipe;

  double _servings = 1;
  final _servingsController = TextEditingController(text: '1');
  bool _showIngredients = false;

  /// Per-ingredient (by index) grams the user typed in, replacing the
  /// servings-derived default. Kept when the servings change - an explicit
  /// "this is what I ate" beats a recalculated default.
  final Map<int, double> _overrides = {};
  List<TextEditingController> _gramsControllers = const [];

  @override
  void dispose() {
    _servingsController.dispose();
    _disposeGramsControllers();
    super.dispose();
  }

  void _disposeGramsControllers() {
    for (final c in _gramsControllers) {
      c.dispose();
    }
  }

  /// The portion being logged: the whole recipe divided by how many times
  /// the servings eaten fit into the recipe's yield.
  RecipePortion get _portion {
    final recipe = _recipe!;
    final divisor = recipe.servings / _servings;
    return RecipePortion(
      recipe,
      divisor: divisor == 1 ? null : divisor,
      overrides: _overrides,
    );
  }

  void _pick(Recipe recipe) {
    setState(() {
      _recipe = recipe;
      _servings = 1;
      _servingsController.text = '1';
      _showIngredients = false;
      _overrides.clear();
      _disposeGramsControllers();
      _gramsControllers = [
        for (var i = 0; i < recipe.ingredients.length; i++)
          TextEditingController(text: _fmt(_portion.defaultGramsFor(i))),
      ];
    });
  }

  void _back() => setState(() => _recipe = null);

  void _setServings(double value) {
    setState(() {
      _servings = value;
      _syncDefaultControllers();
    });
  }

  void _stepServings(double delta) {
    final next = (_servings + delta).clamp(_minServings, _maxServings).toDouble();
    _servingsController.text = _fmt(next);
    _setServings(next);
  }

  void _onServingsTyped(String text) {
    final parsed = parseDecimal(text);
    if (parsed == null || parsed < _minServings || parsed > _maxServings) return;
    _setServings(parsed);
  }

  /// Rewrites the text of every non-overridden amount field after the
  /// servings changed; overridden fields keep what the user typed.
  void _syncDefaultControllers() {
    final portion = _portion;
    for (var i = 0; i < _gramsControllers.length; i++) {
      if (_overrides.containsKey(i)) continue;
      _gramsControllers[i].text = _fmt(portion.defaultGramsFor(i));
    }
  }

  void _onGramsChanged(int index, String text) {
    final parsed = parseDecimal(text);
    if (parsed == null || parsed < 0) return; // keep the last valid value
    setState(() => _overrides[index] = parsed);
  }

  void _resetOverride(int index) {
    setState(() {
      _overrides.remove(index);
      _gramsControllers[index].text = _fmt(_portion.defaultGramsFor(index));
    });
  }

  static String _fmt(double value) {
    final rounded = (value * 100).round() / 100;
    if (rounded == rounded.roundToDouble()) return rounded.round().toString();
    return rounded.toString();
  }

  void _confirm() {
    final recipe = _recipe!;
    final drafts = [
      for (final item in _portion.loggable) (food: item.ingredient.toFood(), grams: item.grams),
    ];
    Navigator.of(context).pop<AddRecipeResult>((recipe: recipe, drafts: drafts));
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.s8,
        AppSpacing.screen,
        AppSpacing.s16 + (viewInsets > 0 ? viewInsets : bottomPad),
      ),
      child: _recipe == null ? _buildPicker(context) : _buildPortion(context),
    );
  }

  // -------------------------------------------------------------------------
  // Step 1 - pick a recipe
  // -------------------------------------------------------------------------

  Widget _buildPicker(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final recipes = ref.watch(recipeControllerProvider);
    final all = recipes.value ?? const <Recipe>[];
    final needle = normalizeForSearch(_query.trim());
    final shown = [
      for (final r in all)
        if (needle.isEmpty || normalizeForSearch(r.name).contains(needle)) r,
    ]..sort(_byFavoriteThenName);
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.addRecipeSheetTitle, style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.s12),
        TextField(
          autofocus: all.isNotEmpty,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchRecipesHint,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          onChanged: (text) => setState(() => _query = text),
        ),
        const SizedBox(height: AppSpacing.s12),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s20),
            child: Text(
              all.isEmpty ? l10n.addRecipeEmpty : l10n.addRecipeNoMatch,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: p.text2),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: SingleChildScrollView(
              child: ListGroup(
                dividerInset: AppSpacing.s16,
                children: [
                  for (final recipe in shown)
                    ListRow(
                      title: recipe.name,
                      subtitle: recipe.ingredients.isEmpty
                          ? l10n.noIngredientsMessage
                          : l10n.addRecipeRowSubtitle(
                              recipe.ingredients.length,
                              f.kcal(recipe.totalCalories / recipe.servings),
                            ),
                      trailing: recipe.favorite ? Icon(Icons.star_rounded, size: 20, color: p.text2) : null,
                      onTap: recipe.ingredients.isEmpty ? null : () => _pick(recipe),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Favourites first, then A-Z (accent-insensitive).
  static int _byFavoriteThenName(Recipe a, Recipe b) {
    if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
    return normalizeForSearch(a.name).compareTo(normalizeForSearch(b.name));
  }

  // -------------------------------------------------------------------------
  // Step 2 - how much of it
  // -------------------------------------------------------------------------

  Widget _buildPortion(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final recipe = _recipe!;
    final portion = _portion;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: _back,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(recipe.name, style: theme.textTheme.headlineSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(l10n.addRecipeServingsLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              IconButton.outlined(
                tooltip: l10n.addRecipeServingsDecreaseTooltip,
                onPressed: _servings <= _minServings ? null : () => _stepServings(-_servingsStep),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: TextField(
                  controller: _servingsController,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                  style: theme.textTheme.titleMedium,
                  decoration: const InputDecoration(isDense: true),
                  onChanged: _onServingsTyped,
                ),
              ),
              IconButton.outlined(
                tooltip: l10n.addRecipeServingsIncreaseTooltip,
                onPressed: _servings >= _maxServings ? null : () => _stepServings(_servingsStep),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showIngredients = !_showIngredients),
              icon: Icon(_showIngredients ? Icons.expand_less : Icons.tune),
              label: Text(l10n.adjustIngredientsButton),
            ),
          ),
          if (_showIngredients) ...[
            Text(l10n.ingredientAmountsHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.s4),
            for (var i = 0; i < recipe.ingredients.length; i++)
              IngredientAmountRow(
                name: recipe.ingredients[i].foodName,
                controller: _gramsControllers[i],
                overridden: _overrides.containsKey(i),
                enabled: true,
                onChanged: (text) => _onGramsChanged(i, text),
                onReset: () => _resetOverride(i),
              ),
          ],
          const SizedBox(height: AppSpacing.s8),
          Text(
            l10n.recipeMacrosPreviewLabel(
              portion.calories.round().toString(),
              f.decimal(portion.protein, 1),
              f.decimal(portion.carbs, 1),
              f.decimal(portion.fat, 1),
            ),
            style: theme.textTheme.bodyMedium,
          ),
          if (!portion.fiberSugar.isEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            FiberSugarLine(totals: portion.fiberSugar),
          ],
          const SizedBox(height: AppSpacing.s20),
          FilledButton(
            onPressed: portion.hasLoggableEntry ? _confirm : null,
            child: Text(l10n.addRecipeConfirm),
          ),
        ],
      ),
    );
  }
}
