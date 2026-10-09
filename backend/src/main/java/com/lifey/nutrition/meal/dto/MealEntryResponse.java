package com.lifey.nutrition.meal.dto;

public record MealEntryResponse(
        Long foodId,
        String foodName,
        Double quantityInGrams,
        Double calories,
        Double protein,
        Double carbs,
        Double fat,
        // Dietary fibre and sugars of this entry (LIF-145); null when the food has no figure, so a total can tell
        // none from not known.
        Double fiber,
        Double sugar
) {
    public MealEntryResponse(Long foodId, String foodName, Double quantityInGrams, Double calories, Double protein,
                             Double carbs, Double fat) {
        this(foodId, foodName, quantityInGrams, calories, protein, carbs, fat, null, null);
    }
}
