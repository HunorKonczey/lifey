package com.lifey.nutrition.recipe.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

import java.util.List;

public record RecipeRequest(

        @NotBlank
        String name,

        @Size(max = 2000)
        String description,

        boolean favorite,

        @NotEmpty
        List<@Valid RecipeIngredientRequest> ingredients
) {
}
