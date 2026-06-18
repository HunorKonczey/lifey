package com.lifey.nutrition.recipe.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record RecipeIngredientRequest(

        @NotNull
        Long foodId,

        @NotNull
        @Positive
        Double quantityInGrams
) {
}
