package com.lifey.nutrition.recipe.dto;

import java.util.List;

public record RecipeResponse(
        Long id,
        String name,
        String description,
        boolean favorite,
        List<RecipeIngredientResponse> ingredients
) {
}
