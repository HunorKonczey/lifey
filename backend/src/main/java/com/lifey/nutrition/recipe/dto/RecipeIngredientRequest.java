package com.lifey.nutrition.recipe.dto;

public record RecipeIngredientRequest(
        Long foodId,
        Double quantityInGrams
) {
}
