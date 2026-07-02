package com.lifey.nutrition.meal;

import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.meal.dto.MealEntryResponse;
import com.lifey.nutrition.meal.dto.MealResponse;

import java.util.List;

/**
 * Maps {@link Meal} entities to meal DTOs. Request-side mapping lives in the
 * service because it needs to resolve {@code foodId}s against the food repository.
 */
public final class MealMapper {

    private MealMapper() {
    }

    public static MealResponse toResponse(Meal meal) {
        List<MealEntryResponse> entries = meal.getEntries().stream()
                .map(entry -> {
                    Food food = entry.getFood();
                    double grams = entry.getQuantityInGrams();
                    double carbsPer100g = food.getCarbsPer100g() != null ? food.getCarbsPer100g() : 0.0;
                    double fatPer100g = food.getFatPer100g() != null ? food.getFatPer100g() : 0.0;
                    return new MealEntryResponse(
                            food.getId(),
                            food.getName(),
                            grams,
                            food.getCaloriesPer100g() * grams / 100.0,
                            food.getProteinPer100g() * grams / 100.0,
                            carbsPer100g * grams / 100.0,
                            fatPer100g * grams / 100.0);
                })
                .toList();

        return new MealResponse(
                meal.getId(),
                meal.getDateTime(),
                meal.getMealType(),
                meal.getName(),
                entries,
                meal.getUpdatedAt(),
                meal.getDeletedAt()
        );
    }
}
