package com.lifey.nutrition.food.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

public record FoodRequest(

        @NotBlank
        String name,

        @NotNull
        @PositiveOrZero
        Double caloriesPer100g,

        @NotNull
        @PositiveOrZero
        Double proteinPer100g,

        @PositiveOrZero
        Double carbsPer100g,

        @PositiveOrZero
        Double fatPer100g,

        String barcode
) {
}
