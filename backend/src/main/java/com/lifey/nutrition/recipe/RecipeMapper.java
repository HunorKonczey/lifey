package com.lifey.nutrition.recipe;

import com.lifey.nutrition.food.Food;
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
                .map(ingredient -> {
                    Food food = ingredient.getFood();
                    double grams = ingredient.getQuantityInGrams();
                    return new RecipeIngredientResponse(
                            food.getId(),
                            food.getName(),
                            grams,
                            food.getCaloriesPer100g() * grams / 100.0,
                            food.getProteinPer100g() * grams / 100.0);
                })
                .toList();

        return new RecipeResponse(
                recipe.getId(),
                recipe.getName(),
                recipe.getDescription(),
                recipe.isFavorite(),
                ingredients
        );
    }
}
