/// Domain model for a recipe.
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    this.description,
    this.ingredients = const [],
  });

  final int id;
  final String name;
  final String? description;
  final List<RecipeIngredient> ingredients;
}

/// A single ingredient within a recipe.
class RecipeIngredient {
  const RecipeIngredient({
    required this.foodId,
    required this.quantityInGrams,
  });

  final int foodId;
  final double quantityInGrams;
}
