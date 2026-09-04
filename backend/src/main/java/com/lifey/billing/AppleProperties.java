package com.lifey.billing;

import com.apple.itunes.storekit.model.Environment;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Bound from {@code lifey.billing.apple.*} (see application.yml). {@code
 * environment} is what THIS server expects every verified transaction to
 * carry — {@code SignedDataVerifier} rejects any transaction whose own
 * embedded environment doesn't match, which is the concrete mechanism behind
 * "the environment must be asserted, not assumed" (64 §11.5): a sandbox
 * transaction can never be accepted by a server configured for production,
 * and vice versa. Defaults to {@code SANDBOX} so a fresh environment doesn't
 * accidentally start in production mode.
 *
 * <p>{@code privateKey}/{@code keyId}/{@code issuerId} are empty by default;
 * {@code StoreBillingServiceImpl}'s App Store Server API confirmation step
 * treats that identically to a real API outage — it fails, is logged, and is
 * swallowed, since local JWS verification alone is already enough to grant
 * Pro (64 §6.1).
 */
@ConfigurationProperties(prefix = "lifey.billing.apple")
public record AppleProperties(
        String bundleId,
        Long appAppleId,
        Environment environment,
        String issuerId,
        String keyId,
        String privateKey
) {
}
