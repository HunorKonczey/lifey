package com.lifey.nutrition.food.dto;

/**
 * One OpenFoodFacts product found by name — the same shape of data as a barcode lookup, not
 * saved anywhere: the client creates a food from it when the user logs it (docs/84 D8).
 * Calories and protein are always present (a hit without them is dropped); carbs and fat
 * may be {@code null} and clients treat that as 0.
 */
public record OffSearchItem(
        String barcode,
        String name,
        String brand,
        Double caloriesPer100g,
        Double proteinPer100g,
        Double carbsPer100g,
        Double fatPer100g,
        Double fiberPer100g,
        Double sugarPer100g
) {
    public OffSearchItem(String barcode, String name, String brand, Double caloriesPer100g, Double proteinPer100g,
                         Double carbsPer100g, Double fatPer100g) {
        this(barcode, name, brand, caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g, null, null);
    }
}
