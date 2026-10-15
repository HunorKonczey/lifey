import '../../nutrition/domain/fiber_sugar.dart';
import '../../nutrition/domain/food.dart';
import 'recipe.dart';

/// One ingredient of a [RecipePortion] with the grams that are actually being
/// logged for it.
typedef PortionIngredient = ({RecipeIngredient ingredient, double grams});

/// How much of a [Recipe] is being logged: the whole recipe divided by
/// [divisor], with optional per-ingredient amounts ([overrides], keyed by
/// ingredient index) replacing the computed ones.
///
/// Pure arithmetic shared by every screen that logs a recipe
/// (`LogRecipeSheet`, the Add-recipe sheet of docs/87). A null [divisor] is
/// the whole recipe, grams exactly as stored; a divisor rounds each
/// ingredient to two decimals. An override of 0 leaves the ingredient out,
/// and an override is an explicit "this is what I ate", so it is never
/// rescaled by a divisor change.
class RecipePortion {
  const RecipePortion(
    this.recipe, {
    this.divisor,
    this.overrides = const {},
  }) : assert(divisor == null || divisor > 0);

  final Recipe recipe;
  final double? divisor;
  final Map<int, double> overrides;

  /// The recipe's own amount of ingredient [index], divided by [divisor] —
  /// what the field shows before the user types anything.
  double defaultGramsFor(int index) => _scaled(recipe.ingredients[index].quantityInGrams);

  /// Grams actually being logged for ingredient [index].
  double gramsFor(int index) => overrides[index] ?? defaultGramsFor(index);

  double _scaled(double grams) {
    final d = divisor;
    if (d == null) return grams;
    return (grams / d * 100).round() / 100;
  }

  double get calories => _scaledTotal((i) => i.calories);
  double get protein => _scaledTotal((i) => i.protein);
  double get carbs => _scaledTotal((i) => i.carbs);
  double get fat => _scaledTotal((i) => i.fat);

  /// Effective total of one macro across all ingredients, each scaled to the
  /// grams actually being logged (overrides included).
  double _scaledTotal(double Function(RecipeIngredient) macroOf) {
    var sum = 0.0;
    final ingredients = recipe.ingredients;
    for (var i = 0; i < ingredients.length; i++) {
      final ingredient = ingredients[i];
      if (ingredient.quantityInGrams <= 0) continue;
      sum += macroOf(ingredient) * gramsFor(i) / ingredient.quantityInGrams;
    }
    return sum;
  }

  /// The logged portion's fibre and sugars (LIF-150), each ingredient scaled
  /// to the grams actually being logged.
  FiberSugarTotals get fiberSugar {
    final entries = <({double? fiber, double? sugar})>[];
    final ingredients = recipe.ingredients;
    for (var i = 0; i < ingredients.length; i++) {
      final ingredient = ingredients[i];
      if (ingredient.quantityInGrams <= 0) continue;
      final scale = gramsFor(i) / ingredient.quantityInGrams;
      entries.add((
        fiber: ingredient.fiber == null ? null : ingredient.fiber! * scale,
        sugar: ingredient.sugar == null ? null : ingredient.sugar! * scale,
      ));
    }
    return FiberSugarTotals.of(entries);
  }

  /// Whether at least one ingredient has a non-zero amount.
  bool get hasLoggableEntry {
    for (var i = 0; i < recipe.ingredients.length; i++) {
      if (gramsFor(i) > 0) return true;
    }
    return false;
  }

  /// The ingredients that will become meal entries, in recipe order — the
  /// ones with a non-zero amount.
  List<PortionIngredient> get loggable => [
        for (var i = 0; i < recipe.ingredients.length; i++)
          if (gramsFor(i) > 0) (ingredient: recipe.ingredients[i], grams: gramsFor(i)),
      ];
}

extension RecipeIngredientFood on RecipeIngredient {
  /// The ingredient as a [Food] with per-100 g figures derived from its own
  /// amounts, the way the meal editor rebuilds the foods of a saved meal's
  /// entries - no repository lookup, so it works offline and for trainer
  /// assigned recipes. A zero-gram ingredient yields zeros.
  Food toFood() {
    final q = quantityInGrams;
    double per100(double v) => q > 0 ? v / q * 100 : 0;
    double? per100OrNull(double? v) => q > 0 && v != null ? v / q * 100 : null;
    return Food(
      clientId: foodClientId,
      name: foodName,
      caloriesPer100g: per100(calories),
      proteinPer100g: per100(protein),
      carbsPer100g: per100(carbs),
      fatPer100g: per100(fat),
      fiberPer100g: per100OrNull(fiber),
      sugarPer100g: per100OrNull(sugar),
    );
  }
}
