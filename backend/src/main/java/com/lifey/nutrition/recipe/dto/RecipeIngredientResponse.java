package com.lifey.nutrition.recipe.dto;

public record RecipeIngredientResponse(
        Long foodId,
        String foodName,
        Double quantityInGrams
) {
}
