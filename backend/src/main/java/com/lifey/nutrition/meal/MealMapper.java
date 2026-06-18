package com.lifey.nutrition.meal;

import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.meal.dto.MealEntryResponse;
import com.lifey.nutrition.meal.dto.MealResponse;

import java.util.List;

/**
 * Maps {@link Meal} entities to meal DTOs. Request-side mapping lives in the
 * service because it needs to resolve {@code foodId}s against the food repository.
 */
final class MealMapper {

    private MealMapper() {
    }

    static MealResponse toResponse(Meal meal) {
        List<MealEntryResponse> entries = meal.getEntries().stream()
                .map(entry -> {
                    Food food = entry.getFood();
                    double grams = entry.getQuantityInGrams();
                    return new MealEntryResponse(
                            food.getId(),
                            food.getName(),
                            grams,
                            food.getCaloriesPer100g() * grams / 100.0,
                            food.getProteinPer100g() * grams / 100.0);
                })
                .toList();

        return new MealResponse(
                meal.getId(),
                meal.getDateTime(),
                meal.getMealType(),
                entries
        );
    }
}
