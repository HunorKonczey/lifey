/// A single ingredient within a recipe (response side). Calories/protein are
/// computed locally (quantity × the food's per-100g macros) rather than
/// fetched from the backend, so they're available offline too.
class RecipeIngredient {
  const RecipeIngredient({
    required this.foodClientId,
    required this.foodName,
    required this.quantityInGrams,
    required this.calories,
    required this.protein,
  });

  final String foodClientId;
  final String foodName;
  final double quantityInGrams;
  final double calories;
  final double protein;
}

/// A recipe with its ingredients (`/recipes`).
class Recipe {
  const Recipe({
    required this.clientId,
    required this.name,
    required this.ingredients,
    this.id,
    this.description,
  });

  final String clientId;
  final int? id;
  final String name;
  final String? description;
  final List<RecipeIngredient> ingredients;

  double get totalCalories =>
      ingredients.fold(0, (sum, i) => sum + i.calories);

  double get totalProtein =>
      ingredients.fold(0, (sum, i) => sum + i.protein);
}
