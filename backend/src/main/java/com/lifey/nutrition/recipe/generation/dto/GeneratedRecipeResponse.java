package com.lifey.nutrition.recipe.generation.dto;

import java.util.List;

/**
 * A proposal, not a saved recipe: nothing is persisted by the generate
 * endpoint. The client edits it and saves through the normal offline-first
 * recipe flow (docs/23-ai-calorie-estimation-plan.md Phase 2).
 *
 * <p>{@code perServing} is computed by the backend from the ingredients and
 * {@code servings} — the same arithmetic the app would do after saving, so the
 * preview cannot disagree with the saved recipe.
 */
public record GeneratedRecipeResponse(
        String name,
        String description,
        int servings,
        List<GeneratedIngredientResponse> ingredients,
        MacroTotals perServing
) {
}
