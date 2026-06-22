package com.lifey.nutrition.meal.dto;

import com.lifey.nutrition.meal.MealType;

import java.time.Instant;
import java.util.List;

public record MealResponse(
        Long id,
        Instant dateTime,
        MealType mealType,
        List<MealEntryResponse> entries
) {
}
