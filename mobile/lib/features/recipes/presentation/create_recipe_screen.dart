import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../nutrition/domain/food.dart';
import '../../nutrition/presentation/widgets/add_macros_sheet.dart';
import '../../nutrition/presentation/widgets/add_meal_entry_sheet.dart';
import '../application/recipes_controller.dart';
import '../data/recipe_repository.dart';
import '../domain/recipe.dart';

/// Full-screen form for creating a recipe, or editing one when [recipe] is given.
class CreateRecipeScreen extends ConsumerStatefulWidget {
  const CreateRecipeScreen({super.key, this.recipe});

  final Recipe? recipe;

  @override
  ConsumerState<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends ConsumerState<CreateRecipeScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  final List<({Food food, double grams})> _ingredients = [];
  bool _saving = false;

  bool get _isEditing => widget.recipe != null;

  double get _totalCalories =>
      _ingredients.fold(0, (s, e) => s + e.food.caloriesPer100g * e.grams / 100);
  double get _totalProtein =>
      _ingredients.fold(0, (s, e) => s + e.food.proteinPer100g * e.grams / 100);
  double get _totalCarbs =>
      _ingredients.fold(0, (s, e) => s + (e.food.carbsPer100g ?? 0) * e.grams / 100);
  double get _totalFat =>
      _ingredients.fold(0, (s, e) => s + (e.food.fatPer100g ?? 0) * e.grams / 100);

  bool get _hasMacroData => _ingredients.any((e) => e.food.caloriesPer100g > 0);

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _name = TextEditingController(text: recipe?.name ?? '');
    _description = TextEditingController(text: recipe?.description ?? '');
    if (recipe != null) {
      for (final ing in recipe.ingredients) {
        final q = ing.quantityInGrams;
        _ingredients.add((
          food: Food(
            clientId: ing.foodClientId,
            name: ing.foodName,
            caloriesPer100g: q > 0 ? ing.calories / q * 100 : 0,
            proteinPer100g: q > 0 ? ing.protein / q * 100 : 0,
            carbsPer100g: q > 0 ? ing.carbs / q * 100 : 0,
            fatPer100g: q > 0 ? ing.fat / q * 100 : 0,
          ),
          grams: q,
        ));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _addIngredient() async {
    final draft = await showModalBottomSheet<MealEntryDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddMealEntrySheet(),
    );
    if (draft != null) {
      setState(() => _ingredients.add((food: draft.food, grams: draft.grams)));
    }
  }

  Future<void> _addMacros() async {
    final draft = await showModalBottomSheet<MealEntryDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddMacrosSheet(),
    );
    if (draft != null) {
      setState(() => _ingredients.add((food: draft.food, grams: draft.grams)));
    }
  }

  Future<void> _editIngredient(int index) async {
    final current = _ingredients[index];
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
      setState(() => _ingredients[index] = (food: draft.food, grams: draft.grams));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (_name.text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.enterANameMessage)));
      return;
    }
    if (_ingredients.isEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.addAtLeastOneIngredientMessage)));
      return;
    }
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final description = _description.text.trim();
    final ingredients = _ingredients
        .map((e) => RecipeIngredientInput(foodClientId: e.food.clientId, grams: e.grams))
        .toList();
    try {
      final notifier = ref.read(recipeControllerProvider.notifier);
      if (_isEditing) {
        await notifier.updateRecipe(
          widget.recipe!.clientId,
          name: _name.text.trim(),
          description: description.isEmpty ? null : description,
          ingredients: ingredients,
        );
      } else {
        await notifier.createRecipe(
          name: _name.text.trim(),
          description: description.isEmpty ? null : description,
          ingredients: ingredients,
        );
      }
      navigator.pop();
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.couldNotSaveRecipeMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusTop = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;
    final mc = context.metricColors;

    return Scaffold(
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────────
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              statusTop + 8 + 58 + 12,
              16,
              bottomPad + 24,
            ),
            children: [
              // ── Name ────────────────────────────────────────────────────
              _SectionLabel(label: l10n.nameLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: l10n.nameLabel,
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Description ─────────────────────────────────────────────
              _SectionLabel(label: l10n.descriptionOptionalLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: l10n.descriptionOptionalLabel,
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 20),

              // ── Ingredients ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionLabel(label: l10n.ingredientsLabel),
                  Row(
                    children: [
                      _SectionActionButton(
                        label: l10n.addMacrosButton,
                        icon: Icons.speed,
                        color: scheme.tertiary,
                        onTap: _addMacros,
                      ),
                      const SizedBox(width: 12),
                      _SectionActionButton(
                        label: l10n.addFoodButton,
                        icon: Icons.add,
                        color: scheme.primary,
                        onTap: _addIngredient,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Ingredient entries
              ..._ingredients.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _IngredientCard(
                      food: e.value.food,
                      grams: e.value.grams,
                      onTap: () => _editIngredient(e.key),
                      onRemove: () => setState(() => _ingredients.removeAt(e.key)),
                    ),
                  )),

              // Dashed "add another ingredient" placeholder
              _AddAnotherButton(
                label: l10n.addFoodButton,
                onTap: _addIngredient,
              ),

              // ── Recipe total ────────────────────────────────────────────
              if (_hasMacroData) ...[
                const SizedBox(height: 12),
                _RecipeTotalCard(
                  label: l10n.mealTotalLabel,
                  calories: _totalCalories,
                  protein: _totalProtein,
                  carbs: _totalCarbs,
                  fat: _totalFat,
                  proteinLabel: l10n.proteinLabel,
                  carbsLabel: l10n.carbsLabel,
                  fatLabel: l10n.fatLabel,
                  mc: mc,
                ),
              ],
            ],
          ),

          // ── Floating header ─────────────────────────────────────────────
          Positioned(
            top: statusTop + 8,
            left: 12,
            right: 12,
            child: _DetailBar(
              title: _isEditing ? l10n.editRecipeTitle : l10n.newRecipeTitle,
              onBack: () => Navigator.of(context).pop(),
              onSave: _saving ? null : _save,
              saving: _saving,
              saveLabel: l10n.saveButton,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating detail header
// ---------------------------------------------------------------------------

class _DetailBar extends StatelessWidget {
  const _DetailBar({
    required this.title,
    required this.onBack,
    required this.onSave,
    required this.saving,
    required this.saveLabel,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onSave;
  final bool saving;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_back,
                      size: 21,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (saving)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                )
              else
                GestureDetector(
                  onTap: onSave,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      saveLabel,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ingredient card
// ---------------------------------------------------------------------------

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({
    required this.food,
    required this.grams,
    required this.onTap,
    required this.onRemove,
  });

  final Food food;
  final double grams;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  String _kcalLabel() {
    if (food.caloriesPer100g <= 0) return '${grams.toStringAsFixed(0)} g';
    final kcal = (food.caloriesPer100g * grams / 100).round();
    return '${grams.toStringAsFixed(0)} g · $kcal kcal';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final mc = context.metricColors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Icon(Icons.restaurant, size: 22, color: mc.carbs),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _kcalLabel(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Icon(Icons.close, size: 19, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Add another" dashed placeholder
// ---------------------------------------------------------------------------

class _AddAnotherButton extends StatelessWidget {
  const _AddAnotherButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: scheme.outline.withValues(alpha: 0.5),
          radius: 18,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 21, color: scheme.onSurfaceVariant),
              const SizedBox(width: 7),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashLen = 6.0;
    const gapLen = 4.0;
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rr);
    final metrics = path.computeMetrics().first;
    double dist = 0;
    while (dist < metrics.length) {
      final end = math.min(dist + dashLen, metrics.length);
      canvas.drawPath(metrics.extractPath(dist, end), paint);
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

// ---------------------------------------------------------------------------
// Recipe total card
// ---------------------------------------------------------------------------

class _RecipeTotalCard extends StatelessWidget {
  const _RecipeTotalCard({
    required this.label,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.proteinLabel,
    required this.carbsLabel,
    required this.fatLabel,
    required this.mc,
  });

  final String label;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String proteinLabel;
  final String carbsLabel;
  final String fatLabel;
  final AppMetricColors mc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(Icons.local_fire_department, size: 18, color: mc.calories),
              const SizedBox(width: 5),
              Text(
                calories.round().toString(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 3),
              Text(
                'kcal',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MacroPill(
                  value: protein,
                  label: proteinLabel,
                  color: mc.protein,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroPill(
                  value: carbs,
                  label: carbsLabel,
                  color: mc.carbs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroPill(
                  value: fat,
                  label: fatLabel,
                  color: mc.fat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.value,
    required this.label,
    required this.color,
  });

  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            '${value.round()} g',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section action button (small icon + label, used in header rows)
// ---------------------------------------------------------------------------

class _SectionActionButton extends StatelessWidget {
  const _SectionActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
