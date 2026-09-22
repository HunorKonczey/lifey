package com.lifey.nutrition.recipe.generation.service;

import com.lifey.nutrition.recipe.generation.dto.GeneratedRecipeResponse;
import com.lifey.nutrition.recipe.generation.dto.RecipeGenerationRequest;

/**
 * AI recipe generation (docs/23-ai-calorie-estimation-plan.md Phase 2).
 * Online-only and stateless: the proposal is not persisted — the client edits
 * it and saves it through the normal offline-first recipe flow. The only thing
 * written here is the monthly AI usage count.
 */
public interface RecipeGenerationService {

    GeneratedRecipeResponse generate(RecipeGenerationRequest request);
}
