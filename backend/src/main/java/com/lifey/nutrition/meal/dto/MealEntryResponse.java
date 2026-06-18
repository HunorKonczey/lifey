package com.lifey.nutrition.meal.dto;

public record MealEntryResponse(
        Long foodId,
        String foodName,
        Double quantityInGrams
) {
}
