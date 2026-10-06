package com.lifey.nutrition.openfoodfacts;

/**
 * One result of an OpenFoodFacts name search, as read from the API — not yet
 * filtered or named for the user (that is the name-search service's job, docs/84 D6).
 * Macros are per 100 g and may be {@code null} when the community data is incomplete.
 *
 * @param code          the barcode
 * @param productName   OFF's {@code product_name}: the product's main-language name
 * @param localizedName the name in the language that was searched ({@code product_name_hu} /
 *                      {@code product_name_en}), {@code null} when nobody entered one
 * @param brands        the distinct brands, comma-separated; {@code null} when there are none
 */
public record OffSearchHit(
        String code,
        String productName,
        String localizedName,
        String brands,
        Double energyKcalPer100g,
        Double proteinsPer100g,
        Double carbohydratesPer100g,
        Double fatPer100g
) {
}
