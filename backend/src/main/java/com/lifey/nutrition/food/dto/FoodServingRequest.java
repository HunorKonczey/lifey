package com.lifey.nutrition.food.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/** One named serving of a food (LIF-146). 5 kg is far more than one serving of anything and catches a grams/kg slip. */
public record FoodServingRequest(

        @NotBlank
        @Size(max = 40)
        String name,

        @NotNull
        @Positive
        @DecimalMax("5000")
        Double grams
) {
}
