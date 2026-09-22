package com.lifey.nutrition.recipe.generation.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * The wizard's answers (docs/23-ai-calorie-estimation-plan.md Phase 2). Every
 * enum is a creative setting, not a contract with the model: new values can be
 * added without touching the request shape.
 *
 * <p>{@code meatType} is only meaningful when the diet allows meat — sending it
 * with {@code VEGETARIAN}/{@code VEGAN} is rejected rather than ignored, so a
 * client bug surfaces instead of quietly producing a vegan recipe "with beef".
 */
public record RecipeGenerationRequest(

        @NotNull
        DietType dietType,

        @NotNull
        MealType mealType,

        @NotNull
        CalorieBand calorieBand,

        MeatType meatType,

        @Size(max = 500)
        String extraRequest
) {

    public boolean hasMeatTypeConflict() {
        return meatType != null && !dietType.allowsMeat();
    }
}
