package com.lifey.nutrition.recipe.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.util.List;

public record RecipeRequest(

        @NotBlank
        String name,

        @Size(max = 2000)
        String description,

        boolean favorite,

        // Nullable for backward compatibility with older clients that don't send
        // it — the service defaults a missing value to 1 (see RecipeServiceImpl).
        @Positive
        Integer servings,

        @NotEmpty
        List<@Valid RecipeIngredientRequest> ingredients
) {
}
