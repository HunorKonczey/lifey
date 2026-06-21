package com.lifey.nutrition.openfoodfacts;

import java.util.Optional;

/**
 * Looks up a product in the OpenFoodFacts catalog by its barcode.
 */
public interface OpenFoodFactsClient {

    /**
     * @return the product, or {@link Optional#empty()} when OpenFoodFacts has no
     * entry for the barcode (HTTP 404, {@code status == 0}, or a missing product).
     */
    Optional<OffProduct> findByBarcode(String barcode);
}
