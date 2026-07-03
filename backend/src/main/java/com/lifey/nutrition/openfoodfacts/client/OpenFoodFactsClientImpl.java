package com.lifey.nutrition.openfoodfacts.client;

import com.lifey.nutrition.openfoodfacts.OffApiResponse;
import com.lifey.nutrition.openfoodfacts.OffProduct;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.Optional;

@Component
class OpenFoodFactsClientImpl implements OpenFoodFactsClient {

    private final RestClient restClient;

    // Explicit constructor (not @RequiredArgsConstructor) so the @Qualifier
    // lands on the actual constructor parameter — Lombok doesn't copy it
    // there by default. Needed since the context now has a second RestClient
    // bean (googleAvatarRestClient, for GoogleAvatarImportListener), making
    // type-only autowiring ambiguous.
    OpenFoodFactsClientImpl(@Qualifier("openFoodFactsRestClient") RestClient restClient) {
        this.restClient = restClient;
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
