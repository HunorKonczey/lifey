package com.lifey.nutrition.recipe.generation.client;

import com.lifey.nutrition.recipe.generation.dto.RecipeGenerationRequest;

/**
 * Asks the model to design a recipe. The seam between the generation service
 * (gating, catalog snapshot, validation, dedup, credit counting) and the Claude
 * API call itself — the counterpart of {@code MealPhotoAnalyzer}.
 */
public interface RecipeGenerator {

    /**
     * @param catalog the user's foods as {@code id | name | kcal/100g} lines,
     * for the model to reference instead of inventing duplicates; may be empty
     * @throws com.lifey.ai.exception.AiUnavailableException when the call fails
     * or yields no usable answer
     * @throws com.lifey.ai.exception.AiNotConfiguredException when no API key is set
     */
    GeneratedRecipe generate(RecipeGenerationRequest request, String catalog);
}
