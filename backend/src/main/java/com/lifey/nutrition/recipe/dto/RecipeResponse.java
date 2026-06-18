package com.lifey.nutrition.recipe.dto;

import java.util.List;

public record RecipeResponse(
        Long id,
        String name,
        String description,
        List<RecipeIngredientResponse> ingredients
) {
}
