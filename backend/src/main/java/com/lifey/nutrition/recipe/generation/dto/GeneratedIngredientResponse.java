package com.lifey.nutrition.recipe.generation.dto;

/**
 * Exactly one of {@code existingFoodId} and {@code newFood} is set. The split
 * is explicit so the client can show "already in your foods" against "will be
 * added" without re-deriving it (docs/23-ai-calorie-estimation-plan.md Phase 2).
 *
 * @param name what to call the ingredient in the preview: the catalog food's
 * own name for an existing food, the proposed name for a new one
 */
public record GeneratedIngredientResponse(
        Long existingFoodId,
        NewFood newFood,
        String name,
        double quantityInGrams
) {

    public record NewFood(
            String name,
            double caloriesPer100g,
            double proteinPer100g,
            double carbsPer100g,
            double fatPer100g
    ) {
    }
}
