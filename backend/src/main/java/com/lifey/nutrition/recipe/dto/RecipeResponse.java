package com.lifey.nutrition.recipe.dto;

import java.time.Instant;
import java.util.List;

public record RecipeResponse(
        Long id,
        String name,
        String description,
        boolean favorite,
        int servings,
        List<RecipeIngredientResponse> ingredients,
        Instant updatedAt,
        Instant deletedAt
) {
}
