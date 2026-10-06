package com.lifey.nutrition.openfoodfacts;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Raw shape of the search-a-licious {@code GET /search} response, narrowed to the
 * fields we request. Unlike the product API, {@code brands} is a list here.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record OffSearchApiResponse(
        List<Hit> hits
) {

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Hit(
            String code,
            @JsonProperty("product_name") String productName,
            @JsonProperty("product_name_hu") String productNameHu,
            @JsonProperty("product_name_en") String productNameEn,
            List<String> brands,
            OffApiResponse.OffApiNutriments nutriments
    ) {
    }
}
