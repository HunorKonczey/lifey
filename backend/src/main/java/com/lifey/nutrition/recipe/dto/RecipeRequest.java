package com.lifey.nutrition.recipe.dto;

import java.util.List;

public record RecipeRequest(
        String name,
        String description,
        List<RecipeIngredientRequest> ingredients
) {
}
