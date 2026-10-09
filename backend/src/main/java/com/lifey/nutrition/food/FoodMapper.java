package com.lifey.nutrition.food;

import com.lifey.nutrition.food.dto.FoodRequest;
import com.lifey.nutrition.food.dto.FoodResponse;
import com.lifey.nutrition.food.dto.FoodServingResponse;

import java.time.Instant;

/**
 * Maps between {@link Food} entities and food DTOs.
 */
public final class FoodMapper {

    private FoodMapper() {
    }

    public static Food toEntity(FoodRequest request) {
        Food food = new Food();
        apply(food, request);
        return food;
    }

    public static void apply(Food food, FoodRequest request) {
        food.setName(request.name().trim());
        food.setCaloriesPer100g(request.caloriesPer100g());
        food.setProteinPer100g(request.proteinPer100g());
        food.setCarbsPer100g(request.carbsPer100g());
        food.setFatPer100g(request.fatPer100g());
        food.setFiberPer100g(request.fiberPer100g());
        food.setSugarPer100g(request.sugarPer100g());
        food.setBarcode(request.barcode());
        food.setHidden(request.hidden());
        if (request.servings() != null) {
            // Replaced as a whole, in the order sent. Only the collection changes here, which Hibernate does not turn into an
            // UPDATE of the food (so @PreUpdate would not move updatedAt) - and delta sync must hand the phones the change.
            food.getServings().clear();
            request.servings().forEach(s -> food.getServings().add(new FoodServing(s.name().trim(), s.grams())));
            food.setUpdatedAt(Instant.now());
        }
    }

    public static FoodResponse toResponse(Food food) {
        return new FoodResponse(
                food.getId(),
                food.getName(),
                food.getCaloriesPer100g(),
                food.getProteinPer100g(),
                food.getCarbsPer100g(),
                food.getFatPer100g(),
                food.getBarcode(),
                food.isHidden(),
                food.getUpdatedAt(),
                food.getDeletedAt(),
                food.getOriginTrainerId(),
                food.getFiberPer100g(),
                food.getSugarPer100g(),
                food.getServings().stream().map(s -> new FoodServingResponse(s.getName(), s.getGrams())).toList()
        );
    }
}
