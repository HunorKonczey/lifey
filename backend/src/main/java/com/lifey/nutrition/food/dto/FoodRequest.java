package com.lifey.nutrition.food.dto;

public record FoodRequest(
        String name,
        Double caloriesPer100g,
        Double proteinPer100g,
        Double carbsPer100g,
        Double fatPer100g
) {
}
