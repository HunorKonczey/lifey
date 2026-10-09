package com.lifey.nutrition.food.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.util.List;

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

        String barcode,

        boolean hidden,

        /** Optional dietary fibre and sugars per 100 g (LIF-145); absent = not known. */
        @PositiveOrZero
        Double fiberPer100g,

        @PositiveOrZero
        Double sugarPer100g,

        /**
         * Named serving sizes (LIF-146). Absent (null) keeps what is stored - a client that does not know the field must not
         * erase it - and an empty list clears them. At most 10, replaced as a whole.
         */
        @Size(max = 10)
        List<@Valid FoodServingRequest> servings
) {
    public FoodRequest(String name, Double caloriesPer100g, Double proteinPer100g, Double carbsPer100g,
                       Double fatPer100g, String barcode, boolean hidden, Double fiberPer100g, Double sugarPer100g) {
        this(name, caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g, barcode, hidden, fiberPer100g, sugarPer100g, null);
    }

    public FoodRequest(String name, Double caloriesPer100g, Double proteinPer100g, Double carbsPer100g,
                       Double fatPer100g, String barcode, boolean hidden) {
        this(name, caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g, barcode, hidden, null, null, null);
    }
}
