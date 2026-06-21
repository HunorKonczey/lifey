package com.lifey.nutrition.food.dto;

/**
 * Result of a barcode lookup. When {@code source} is {@link BarcodeSource#LOCAL},
 * {@code id} is the existing {@code Food}'s id and the entry is already in our
 * catalog. When {@code source} is {@link BarcodeSource#OPENFOODFACTS}, {@code id}
 * is {@code null} — the data came straight from OpenFoodFacts and has not been
 * saved; the client must POST {@code /foods} to persist it.
 */
public record BarcodeLookupResponse(
        Long id,
        String name,
        Double caloriesPer100g,
        Double proteinPer100g,
        Double carbsPer100g,
        Double fatPer100g,
        String barcode,
        BarcodeSource source
) {
}
