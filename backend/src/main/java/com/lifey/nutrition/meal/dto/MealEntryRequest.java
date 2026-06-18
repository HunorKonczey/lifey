package com.lifey.nutrition.meal.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record MealEntryRequest(

        @NotNull
        Long foodId,

        @NotNull
        @Positive
        Double quantityInGrams
) {
}
