package com.lifey.nutrition.openfoodfacts;

/**
 * The subset of an OpenFoodFacts product we care about, already extracted from
 * the raw API response. Macros are per 100g and may be {@code null} when the
 * community data is incomplete.
 */
public record OffProduct(
        String name,
        String brands,
        Double energyKcalPer100g,
        Double proteinsPer100g,
        Double carbohydratesPer100g,
        Double fatPer100g
) {
}
