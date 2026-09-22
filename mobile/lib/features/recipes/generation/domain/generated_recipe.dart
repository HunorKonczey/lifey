/// A recipe proposal from `POST /recipes/generate`
/// (docs/23-ai-calorie-estimation-plan.md Phase 2). Transient and online-only:
/// nothing is stored until the user saves it, and then it is saved as an
/// ordinary recipe through the offline-first flow.
class GeneratedRecipe {
  const GeneratedRecipe({
    required this.name,
    required this.description,
    required this.servings,
    required this.ingredients,
    required this.perServing,
  });

  final String name;
  final String? description;
  final int servings;
  final List<GeneratedIngredient> ingredients;
  final RecipeMacros perServing;

  factory GeneratedRecipe.fromJson(Map<String, dynamic> json) {
    return GeneratedRecipe(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      servings: (json['servings'] as num?)?.toInt() ?? 1,
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((e) => GeneratedIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      perServing: RecipeMacros.fromJson(json['perServing'] as Map<String, dynamic>),
    );
  }
}

/// Exactly one of [existingFoodId] (a food the user already has, by server id)
/// and [newFood] (to be created on save) is set.
class GeneratedIngredient {
  const GeneratedIngredient({
    required this.name,
    required this.quantityInGrams,
    this.existingFoodId,
    this.newFood,
  });

  final String name;
  final double quantityInGrams;
  final int? existingFoodId;
  final GeneratedNewFood? newFood;

  bool get isNew => newFood != null;

  factory GeneratedIngredient.fromJson(Map<String, dynamic> json) {
    final newFood = json['newFood'] as Map<String, dynamic>?;
    return GeneratedIngredient(
      name: json['name'] as String,
      quantityInGrams: (json['quantityInGrams'] as num).toDouble(),
      existingFoodId: (json['existingFoodId'] as num?)?.toInt(),
      newFood: newFood == null ? null : GeneratedNewFood.fromJson(newFood),
    );
  }
}

class GeneratedNewFood {
  const GeneratedNewFood({
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });

  final String name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  factory GeneratedNewFood.fromJson(Map<String, dynamic> json) {
    return GeneratedNewFood(
      name: json['name'] as String,
      caloriesPer100g: (json['caloriesPer100g'] as num).toDouble(),
      proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
      carbsPer100g: (json['carbsPer100g'] as num).toDouble(),
      fatPer100g: (json['fatPer100g'] as num).toDouble(),
    );
  }
}

class RecipeMacros {
  const RecipeMacros({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  factory RecipeMacros.fromJson(Map<String, dynamic> json) {
    return RecipeMacros(
      calories: (json['calories'] as num).toDouble(),
      protein: (json['proteinGrams'] as num).toDouble(),
      carbs: (json['carbsGrams'] as num).toDouble(),
      fat: (json['fatGrams'] as num).toDouble(),
    );
  }
}
