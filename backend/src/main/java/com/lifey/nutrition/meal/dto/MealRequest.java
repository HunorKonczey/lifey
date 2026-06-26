package com.lifey.nutrition.meal.dto;

import com.lifey.nutrition.meal.MealType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;

public record MealRequest(

        @NotNull
        @PastOrPresent
        Instant dateTime,

        @NotNull
        MealType mealType,

        @Size(max = 255)
        String name,

        @NotEmpty
        List<@Valid MealEntryRequest> entries
) {
}
