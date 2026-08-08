package com.lifey.auth;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Bound from {@code lifey.jwt.*}.
 *
 * <p>Only two fields, against the monolith's four: this service verifies tokens
 * and never issues them, so the two TTLs have no meaning here. The {@code secret}
 * must be <b>bit-identical</b> to {@code lifey-api}'s — that is the entire trust
 * relationship between the two services (§5.3), and a mismatch shows up as every
 * chat request returning 401.
 *
 * @param issuer expected {@code iss} claim. Verified rather than ignored so a
 *               token minted by some other system that happened to share the
 *               secret still cannot get in.
 */
@ConfigurationProperties(prefix = "lifey.jwt")
public record JwtProperties(
        String secret,
        String issuer
) {
}
