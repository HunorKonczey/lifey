package com.lifey.nutrition.openfoodfacts.client;

import com.lifey.nutrition.openfoodfacts.OffProduct;
import com.lifey.nutrition.openfoodfacts.OffSearchHit;

import java.util.List;
import java.util.Optional;

/**
 * Talks to OpenFoodFacts: a product by barcode, or products by name.
 */
public interface OpenFoodFactsClient {

    /**
     * @return the product, or {@link Optional#empty()} when OpenFoodFacts has no
     * entry for the barcode (HTTP 404, {@code status == 0}, or a missing product).
     */
    Optional<OffProduct> findByBarcode(String barcode);

    /**
     * Full-text search by product name (docs/84), via OFF's search-a-licious service.
     *
     * <p>The text is sanitised first ({@code OffSearchQuery}); when nothing searchable is left
     * the result is empty and OFF is not called. Hits without a barcode are skipped. The result
     * is raw: not yet filtered for usable nutrition, nor named for the user.
     *
     * @param query      what the user typed
     * @param lang       the language whose name fields are searched, {@code hu} or {@code en}
     *                   (anything else is treated as {@code en})
     * @param countryTag an OFF country tag such as {@code en:hungary} to restrict the search to
     *                   products sold there, or {@code null} for no restriction
     * @param limit      the most hits to return (1 to 50)
     * @return the hits in OFF's relevance order — empty when nothing matched
     * @throws com.lifey.nutrition.openfoodfacts.exception.OffRateLimitedException when OFF
     *                                                                             answers 429 or 503
     * @throws com.lifey.nutrition.openfoodfacts.exception.OffUnavailableException for any other
     *                                                                             failure: timeout, connection error, 5xx, unreadable body
     */
    List<OffSearchHit> searchByName(String query, String lang, String countryTag, int limit);
}
