package com.lifey.nutrition.meal.dto;

public record MealEntryRequest(
        Long foodId,
        Double quantityInGrams
) {
}
