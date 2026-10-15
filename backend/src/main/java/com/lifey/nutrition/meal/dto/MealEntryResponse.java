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
        Double sugar,
        // The recipe this entry was added as part of, and its current name (docs/88); both null for a plain entry. The
        // name is here so a reader that does not own the recipe - the trainer - can still say which recipe it was.
        Long recipeId,
        String recipeName
) {
    public MealEntryResponse(Long foodId, String foodName, Double quantityInGrams, Double calories, Double protein,
                             Double carbs, Double fat, Double fiber, Double sugar) {
        this(foodId, foodName, quantityInGrams, calories, protein, carbs, fat, fiber, sugar, null, null);
    }

    public MealEntryResponse(Long foodId, String foodName, Double quantityInGrams, Double calories, Double protein,
                             Double carbs, Double fat) {
        this(foodId, foodName, quantityInGrams, calories, protein, carbs, fat, null, null, null, null);
    }
}
