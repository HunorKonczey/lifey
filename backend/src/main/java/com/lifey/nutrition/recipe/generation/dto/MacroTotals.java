package com.lifey.nutrition.recipe.generation.dto;

/**
 * Energy and macros for one serving. Fibre and sugars (LIF-150) are the sum of what is known: an existing food of the user's
 * can have no figure ("not known" is not 0), so they are null when no ingredient has one and {@code fiberSugarPartial} when
 * only some do - the same rule as a meal's or a day's total.
 */
public record MacroTotals(
        double calories,
        double proteinGrams,
        double carbsGrams,
        double fatGrams,
        Double fiberGrams,
        Double sugarGrams,
        boolean fiberSugarPartial
) {

    public MacroTotals(double calories, double proteinGrams, double carbsGrams, double fatGrams) {
        this(calories, proteinGrams, carbsGrams, fatGrams, null, null, false);
    }
}
