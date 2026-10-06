package com.lifey.nutrition.openfoodfacts.client;

import com.lifey.nutrition.openfoodfacts.OffApiResponse;
import com.lifey.nutrition.openfoodfacts.OffProduct;
import com.lifey.nutrition.openfoodfacts.OffSearchApiResponse;
import com.lifey.nutrition.openfoodfacts.OffSearchHit;
import com.lifey.nutrition.openfoodfacts.OffSearchQuery;
import com.lifey.nutrition.openfoodfacts.exception.OffRateLimitedException;
import com.lifey.nutrition.openfoodfacts.exception.OffUnavailableException;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.List;
import java.util.Objects;
import java.util.Optional;

@Component
class OpenFoodFactsClientImpl implements OpenFoodFactsClient {

    /** Only what the name search reads — smaller responses, and the fields the spike verified. */
    private static final String SEARCH_FIELDS = "code,product_name,product_name_hu,product_name_en,brands,nutriments";
    private static final int MAX_SEARCH_LIMIT = 50;

    private final RestClient restClient;
    private final RestClient searchRestClient;

    // Explicit constructor (not @RequiredArgsConstructor) so the @Qualifier
    // lands on the actual constructor parameter — Lombok doesn't copy it
    // there by default. Needed since the context has several RestClient
    // beans (googleAvatarRestClient, and OFF's own product and search clients),
    // making type-only autowiring ambiguous.
    OpenFoodFactsClientImpl(@Qualifier("openFoodFactsRestClient") RestClient restClient,
                            @Qualifier("openFoodFactsSearchRestClient") RestClient searchRestClient) {
        this.restClient = restClient;
        this.searchRestClient = searchRestClient;
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

    @Override
    public List<OffSearchHit> searchByName(String query, String lang, String countryTag, int limit) {
        String text = OffSearchQuery.sanitize(query);
        if (text.isEmpty()) {
            return List.of();
        }
        boolean hungarian = "hu".equals(lang);
        // The country restriction is appended after the sanitised text as a fixed clause, so what
        // the user typed can never alter or drop it (docs/84 D11/D12).
        String q = countryTag == null || countryTag.isBlank() ? text : text + " countries_tags:\"" + countryTag + "\"";

        OffSearchApiResponse response;
        try {
            response = searchRestClient.get()
                    .uri("/search?q={q}&langs={langs}&page_size={size}&fields={fields}",
                            q, hungarian ? "hu" : "en", Math.min(Math.max(limit, 1), MAX_SEARCH_LIMIT), SEARCH_FIELDS)
                    .retrieve()
                    // 429, and 503 — which is what OFF answers when its global limits are hit.
                    .onStatus(status -> status.value() == 429 || status.value() == 503, (request, clientResponse) -> {
                        throw new OffRateLimitedException("OpenFoodFacts search rate-limited (HTTP "
                                + clientResponse.getStatusCode().value() + ")");
                    })
                    .onStatus(status -> status.isError(), (request, clientResponse) -> {
                        throw new OffUnavailableException("OpenFoodFacts search failed (HTTP "
                                + clientResponse.getStatusCode().value() + ")");
                    })
                    .body(OffSearchApiResponse.class);
        } catch (RestClientException e) {
            // Timeout, connection failure, or a body that could not be read.
            throw new OffUnavailableException("OpenFoodFacts search unavailable", e);
        }

        if (response == null || response.hits() == null) {
            return List.of();
        }
        return response.hits().stream()
                .filter(Objects::nonNull)
                .filter(hit -> hit.code() != null && !hit.code().isBlank())
                .map(hit -> toSearchHit(hit, hungarian))
                .toList();
    }

    private static OffSearchHit toSearchHit(OffSearchApiResponse.Hit hit, boolean hungarian) {
        OffApiResponse.OffApiNutriments n = hit.nutriments();
        return new OffSearchHit(
                hit.code().trim(),
                hit.productName(),
                hungarian ? hit.productNameHu() : hit.productNameEn(),
                joinBrands(hit.brands()),
                n != null ? n.energyKcal100g() : null,
                n != null ? n.proteins100g() : null,
                n != null ? n.carbohydrates100g() : null,
                n != null ? n.fat100g() : null
        );
    }

    /** OFF lists brands as an array that often repeats itself and carries stray spaces. */
    private static String joinBrands(List<String> brands) {
        if (brands == null) {
            return null;
        }
        return brands.stream()
                .filter(Objects::nonNull)
                .map(String::trim)
                .filter(b -> !b.isEmpty())
                .distinct()
                .reduce((a, b) -> a + ", " + b)
                .orElse(null);
    }
}
