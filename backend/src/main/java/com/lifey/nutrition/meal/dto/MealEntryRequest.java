package com.lifey.nutrition.meal.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record MealEntryRequest(

        @NotNull
        Long foodId,

        @NotNull
        @Positive
        Double quantityInGrams,

        /**
         * The recipe this entry belongs to (docs/88), when it was added as part of one. Absent (null) means "not from a
         * recipe": a meal update replaces all entries, so a client that leaves it out clears the tag.
         */
        Long recipeId
) {
    public MealEntryRequest(Long foodId, Double quantityInGrams) {
        this(foodId, quantityInGrams, null);
    }
}
