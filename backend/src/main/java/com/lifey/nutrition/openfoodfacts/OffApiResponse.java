package com.lifey.nutrition.openfoodfacts;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Raw shape of the OpenFoodFacts v2 {@code /product/{barcode}.json} response,
 * narrowed to the fields we read. {@code status} is {@code 1} when the product
 * was found and {@code 0} otherwise. All other fields are ignored.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
record OffApiResponse(
        int status,
        OffApiProduct product
) {

    @JsonIgnoreProperties(ignoreUnknown = true)
    record OffApiProduct(
            @JsonProperty("product_name") String productName,
            String brands,
            OffApiNutriments nutriments
    ) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record OffApiNutriments(
            @JsonProperty("energy-kcal_100g") Double energyKcal100g,
            @JsonProperty("proteins_100g") Double proteins100g,
            @JsonProperty("carbohydrates_100g") Double carbohydrates100g,
            @JsonProperty("fat_100g") Double fat100g
    ) {
    }
}
