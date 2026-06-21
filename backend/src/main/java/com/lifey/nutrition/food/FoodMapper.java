package com.lifey.nutrition.food;

import com.lifey.nutrition.food.dto.FoodRequest;
import com.lifey.nutrition.food.dto.FoodResponse;

/**
 * Maps between {@link Food} entities and food DTOs.
 */
final class FoodMapper {

    private FoodMapper() {
    }

    static Food toEntity(FoodRequest request) {
        Food food = new Food();
        apply(food, request);
        return food;
    }

    static void apply(Food food, FoodRequest request) {
        food.setName(request.name().trim());
        food.setCaloriesPer100g(request.caloriesPer100g());
        food.setProteinPer100g(request.proteinPer100g());
        food.setCarbsPer100g(request.carbsPer100g());
        food.setFatPer100g(request.fatPer100g());
        food.setBarcode(request.barcode());
    }

    static FoodResponse toResponse(Food food) {
        return new FoodResponse(
                food.getId(),
                food.getName(),
                food.getCaloriesPer100g(),
                food.getProteinPer100g(),
                food.getCarbsPer100g(),
                food.getFatPer100g(),
                food.getBarcode()
        );
    }
}
