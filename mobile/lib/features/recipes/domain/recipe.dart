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
    required this.carbs,
    required this.fat,
  });

  final String foodClientId;
  final String foodName;
  final double quantityInGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
}

/// A recipe with its ingredients (`/recipes`).
class Recipe {
  const Recipe({
    required this.clientId,
    required this.name,
    required this.ingredients,
    this.id,
    this.description,
    this.favorite = false,
    this.servings = 1,
    this.originTrainerId,
    this.imageUpdatedAt,
  });

  final String clientId;
  final int? id;
  final String name;
  final String? description;
  final bool favorite;
  final int servings;
  final List<RecipeIngredient> ingredients;

  /// Non-null only for a trainer-assigned copy (docs/personal_trainer/05-mobil-terv.md
  /// §2) — the trainer's server-side user id, drives the "Edzőtől" badge.
  final int? originTrainerId;

  /// Null if no photo is set. See RecipeImageRepository for how the app uses
  /// this to decide when to (re-)download the photo.
  final DateTime? imageUpdatedAt;

  double get totalCalories =>
      ingredients.fold(0, (sum, i) => sum + i.calories);

  double get totalProtein =>
      ingredients.fold(0, (sum, i) => sum + i.protein);

  double get totalCarbs => ingredients.fold(0, (sum, i) => sum + i.carbs);

  double get totalFat => ingredients.fold(0, (sum, i) => sum + i.fat);
}
