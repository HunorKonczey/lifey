package com.lifey.nutrition.openfoodfacts;

import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.Optional;

@Component
class OpenFoodFactsClientImpl implements OpenFoodFactsClient {

    private final RestClient restClient;

    OpenFoodFactsClientImpl(RestClient openFoodFactsRestClient) {
        this.restClient = openFoodFactsRestClient;
    }

    @Override
    public Optional<OffProduct> findByBarcode(String barcode) {
        OffApiResponse response = restClient.get()
                .uri("/api/v2/product/{barcode}.json", barcode)
                // OFF returns a JSON body with status 0 even for unknown products,
                // but a hard 404 is possible too — swallow it and treat as "no data".
                .retrieve()
                .onStatus(status -> status.value() == 404, (request, clientResponse) -> {
                })
                .body(OffApiResponse.class);

        if (response == null || response.status() == 0 || response.product() == null) {
            return Optional.empty();
        }

        OffApiResponse.OffApiProduct product = response.product();
        OffApiResponse.OffApiNutriments nutriments = product.nutriments();

        return Optional.of(new OffProduct(
                product.productName(),
                product.brands(),
                nutriments != null ? nutriments.energyKcal100g() : null,
                nutriments != null ? nutriments.proteins100g() : null,
                nutriments != null ? nutriments.carbohydrates100g() : null,
                nutriments != null ? nutriments.fat100g() : null
        ));
    }
}
