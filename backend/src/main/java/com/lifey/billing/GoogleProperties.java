package com.lifey.billing;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Bound from {@code lifey.billing.google.*} (see application.yml).
 * {@code serviceAccountJson} is the raw content of the service-account key
 * downloaded from Google Cloud Console, empty by default — {@code
 * PlayPurchaseClientImpl} builds the real {@code AndroidPublisher} client
 * fresh on every call rather than as an eagerly-constructed bean, since
 * {@code GoogleCredentials.fromStream} parses the key immediately and would
 * otherwise fail application startup with no key configured (64 §6.1).
 *
 * <p>{@code pubsubAudience}/{@code pubsubServiceAccountEmail} are `64` §6.2's
 * Play RTDN webhook — the audience the Pub/Sub push subscription was
 * configured with (normally the webhook's own URL) and the service account
 * email that subscription signs its OIDC push tokens with. Both empty by
 * default, so {@code PubSubTokenVerifier} rejects every token until they're set.
 */
@ConfigurationProperties(prefix = "lifey.billing.google")
public record GoogleProperties(
        String packageName,
        String serviceAccountJson,
        String pubsubAudience,
        String pubsubServiceAccountEmail
) {
}
