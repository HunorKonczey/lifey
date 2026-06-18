/// A single ingredient within a recipe (response side).
class RecipeIngredient {
  const RecipeIngredient({
    required this.foodId,
    required this.foodName,
    required this.quantityInGrams,
    required this.calories,
    required this.protein,
  });

  final int foodId;
  final String foodName;
  final double quantityInGrams;
  final double calories;
  final double protein;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      foodId: json['foodId'] as int,
      foodName: json['foodName'] as String? ?? 'Unknown',
      quantityInGrams: (json['quantityInGrams'] as num).toDouble(),
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A recipe with its ingredients (`/recipes`).
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    this.description,
  });

  final int id;
  final String name;
  final String? description;
  final List<RecipeIngredient> ingredients;

  double get totalCalories =>
      ingredients.fold(0, (sum, i) => sum + i.calories);

  double get totalProtein =>
      ingredients.fold(0, (sum, i) => sum + i.protein);

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final ingredients = (json['ingredients'] as List<dynamic>? ?? const [])
        .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
        .toList();
    return Recipe(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      ingredients: ingredients,
    );
  }
}
