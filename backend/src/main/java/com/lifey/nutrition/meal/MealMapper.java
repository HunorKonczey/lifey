package com.lifey.nutrition.meal;

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
                .map(entry -> new MealEntryResponse(
                        entry.getFood().getId(),
                        entry.getFood().getName(),
                        entry.getQuantityInGrams()))
                .toList();

        return new MealResponse(
                meal.getId(),
                meal.getDateTime(),
                meal.getMealType(),
                entries
        );
    }
}
