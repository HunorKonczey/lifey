package com.lifey.nutrition.openfoodfacts;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Bound from {@code lifey.openfoodfacts.*} (see application.yml).
 *
 * <p>OpenFoodFacts is a community-run service that requires every client to send
 * a descriptive {@code User-Agent} identifying the app and a contact; the base
 * URL is overridable so tests can point at a stub and deployments can switch
 * between the {@code world} and a localized instance.
 *
 * <p>Name search (docs/84) talks to a different host, the full-text
 * search-a-licious service ({@code searchBaseUrl}); {@code searchPerMinute} is the
 * app-wide cap on those calls (used by the limiter, docs/84 D7) and
 * {@code huCountryTag} the OFF country tag a Hungarian-language search is
 * restricted to (docs/84 D12).
 */
@ConfigurationProperties(prefix = "lifey.openfoodfacts")
public record OpenFoodFactsProperties(
        String baseUrl,
        String userAgent,
        String searchBaseUrl,
        int searchPerMinute,
        String huCountryTag
) {
}
