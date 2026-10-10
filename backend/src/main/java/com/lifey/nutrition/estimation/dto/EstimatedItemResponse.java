package com.lifey.nutrition.estimation.dto;

import com.lifey.nutrition.estimation.client.EstimationConfidence;

/**
 * One recognized food. Calories and macros are for {@code estimatedGrams}, not
 * per 100 g — that is what the user sees and edits; the per-100 g conversion
 * happens on the client at save time (docs/23-ai-calorie-estimation-plan.md).
 * Fibre and sugars (LIF-152) are the model's estimate for the same portion; a
 * {@code null} one is not known (not 0) and the saved food keeps it unknown.
 */
public record EstimatedItemResponse(
        String name,
        double estimatedGrams,
        double calories,
        double proteinGrams,
        double carbsGrams,
        double fatGrams,
        Double fiberGrams,
        Double sugarGrams,
        EstimationConfidence confidence
) {

    public EstimatedItemResponse(String name, double estimatedGrams, double calories, double proteinGrams,
                                 double carbsGrams, double fatGrams, EstimationConfidence confidence) {
        this(name, estimatedGrams, calories, proteinGrams, carbsGrams, fatGrams, null, null, confidence);
    }
}
