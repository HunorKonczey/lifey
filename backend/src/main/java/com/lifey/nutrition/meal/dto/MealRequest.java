package com.lifey.nutrition.meal.dto;

import com.lifey.nutrition.meal.MealType;

import java.time.LocalDateTime;
import java.util.List;

public record MealRequest(
        LocalDateTime dateTime,
        MealType mealType,
        List<MealEntryRequest> entries
) {
}
