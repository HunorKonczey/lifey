package com.lifey.nutrition.food.dto;

/**
 * Where a {@link BarcodeLookupResponse} came from: an existing entry in our
 * own shared food catalog, or a live OpenFoodFacts lookup that hasn't been
 * persisted yet.
 */
public enum BarcodeSource {
    LOCAL,
    OPENFOODFACTS
}
