package com.lifey.nutrition.estimation.client;

import com.fasterxml.jackson.annotation.JsonPropertyDescription;

import java.util.List;

/**
 * The model's answer, as a structured-output schema: the SDK derives the JSON
 * schema from these records, so the descriptions below are part of the prompt.
 * Values are for the estimated portion, not per 100 g
 * (docs/23-ai-calorie-estimation-plan.md "Endpoint").
 */
public record MealPhotoEstimate(
        @JsonPropertyDescription("Each distinct food item visible in the photo; empty if there is no food")
        List<Item> items,
        @JsonPropertyDescription("A short caveat for the user, or an empty string")
        String notes
) {

    public record Item(
            @JsonPropertyDescription("Short English name of the food, e.g. \"Grilled chicken breast\"")
            String name,
            @JsonPropertyDescription("Estimated portion weight in grams")
            double estimatedGrams,
            @JsonPropertyDescription("Energy in kcal for the estimated portion")
            double calories,
            @JsonPropertyDescription("Protein in grams for the estimated portion")
            double proteinGrams,
            @JsonPropertyDescription("Carbohydrates in grams for the estimated portion")
            double carbsGrams,
            @JsonPropertyDescription("Fat in grams for the estimated portion")
            double fatGrams,
            EstimationConfidence confidence
    ) {
    }
}
