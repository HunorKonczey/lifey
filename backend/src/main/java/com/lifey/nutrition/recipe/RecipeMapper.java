package com.lifey.nutrition.recipe;

import com.lifey.nutrition.recipe.dto.RecipeIngredientResponse;
import com.lifey.nutrition.recipe.dto.RecipeResponse;

import java.util.List;

/**
 * Maps {@link Recipe} entities to recipe DTOs. Request-side mapping lives in the
 * service because it needs to resolve {@code foodId}s against the food repository.
 */
final class RecipeMapper {

    private RecipeMapper() {
    }

    static RecipeResponse toResponse(Recipe recipe) {
        List<RecipeIngredientResponse> ingredients = recipe.getIngredients().stream()
                .map(ingredient -> new RecipeIngredientResponse(
                        ingredient.getFood().getId(),
                        ingredient.getFood().getName(),
                        ingredient.getQuantityInGrams()))
                .toList();

        return new RecipeResponse(
                recipe.getId(),
                recipe.getName(),
                recipe.getDescription(),
                ingredients
        );
    }
}
