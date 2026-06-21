package com.lifey.nutrition.openfoodfacts;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Bound from {@code lifey.openfoodfacts.*} (see application.yml).
 *
 * <p>OpenFoodFacts is a community-run service that requires every client to send
 * a descriptive {@code User-Agent} identifying the app and a contact; the base
 * URL is overridable so tests can point at a stub and deployments can switch
 * between the {@code world} and a localized instance.
 */
@ConfigurationProperties(prefix = "lifey.openfoodfacts")
public record OpenFoodFactsProperties(
        String baseUrl,
        String userAgent
) {
}
