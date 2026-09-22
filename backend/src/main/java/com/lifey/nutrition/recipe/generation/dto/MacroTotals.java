package com.lifey.nutrition.recipe.generation.dto;

/** Energy and macros for one serving. */
public record MacroTotals(
        double calories,
        double proteinGrams,
        double carbsGrams,
        double fatGrams
) {
}
