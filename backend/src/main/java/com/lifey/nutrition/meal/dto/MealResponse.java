package com.lifey.nutrition.meal.dto;

import com.lifey.nutrition.meal.MealType;

import java.time.LocalDateTime;
import java.util.List;

public record MealResponse(
        Long id,
        LocalDateTime dateTime,
        MealType mealType,
        List<MealEntryResponse> entries
) {
}
