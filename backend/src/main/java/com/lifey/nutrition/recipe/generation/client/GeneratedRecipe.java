package com.lifey.nutrition.recipe.generation.client;

import com.fasterxml.jackson.annotation.JsonPropertyDescription;

import java.util.List;

/**
 * The model's answer, as a structured-output schema: the SDK derives the JSON
 * schema from these records, so the descriptions below are part of the prompt.
 *
 * <p><b>Why {@code existingFoodId = 0} instead of a nullable field.</b> An
 * ingredient is either one of the user's foods or a new one, which is a union —
 * and a union is exactly what a derived, all-fields-required schema expresses
 * badly. A sentinel keeps the schema flat and unambiguous for the model; the
 * service turns it back into the explicit two-shape DTO the client sees
 * (docs/23-ai-calorie-estimation-plan.md Phase 2 "Food deduplication").
 */
public record GeneratedRecipe(
        @JsonPropertyDescription("Short recipe name, max 80 characters")
        String name,
        @JsonPropertyDescription("Numbered preparation steps as plain text, max 1800 characters")
        String description,
        @JsonPropertyDescription("How many servings the ingredient quantities make, 1-12")
        int servings,
        List<Ingredient> ingredients
) {

    public record Ingredient(
            @JsonPropertyDescription("Ingredient name; for an existing food, the catalog's own name")
            String name,
            @JsonPropertyDescription("Amount in grams for the whole recipe, not per serving")
            double quantityInGrams,
            @JsonPropertyDescription("The id from the user's food list when this is one of those foods, "
                    + "otherwise 0")
            long existingFoodId,
            @JsonPropertyDescription("Energy per 100 g; only used when existingFoodId is 0")
            double caloriesPer100g,
            @JsonPropertyDescription("Protein per 100 g; only used when existingFoodId is 0")
            double proteinPer100g,
            @JsonPropertyDescription("Carbohydrate per 100 g; only used when existingFoodId is 0")
            double carbsPer100g,
            @JsonPropertyDescription("Fat per 100 g; only used when existingFoodId is 0")
            double fatPer100g
    ) {

        public boolean claimsExistingFood() {
            return existingFoodId > 0;
        }
    }
}
