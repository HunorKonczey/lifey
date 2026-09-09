package com.lifey.billing;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Set;

/**
 * Verifies the OIDC bearer token a Google Cloud Pub/Sub push subscription
 * attaches to every delivery (docs/landing_page/64-billing-backend-plan.md
 * §6.2 — the Play RTDN webhook) against Google's published JWKS. Deliberately
 * separate from {@code com.lifey.auth.GoogleIdTokenVerifier}: that one checks
 * a Google Sign-In audience (an OAuth client id); this one checks a Pub/Sub
 * push audience (the webhook's own URL) and a specific service-account email
 * — two different trust domains that happen to share an issuer.
 */
@Service
@Slf4j
public class PubSubTokenVerifier {

    private static final Set<String> VALID_ISSUERS = Set.of("https://accounts.google.com", "accounts.google.com");

    private final JwtDecoder jwtDecoder;
    private final GoogleProperties properties;

    @Autowired
    PubSubTokenVerifier(GoogleProperties properties) {
        this(properties, NimbusJwtDecoder.withJwkSetUri("https://www.googleapis.com/oauth2/v3/certs").build());
    }

    /** Visible for tests, to inject a decoder backed by a local JWK set instead of Google's live JWKS. */
    PubSubTokenVerifier(GoogleProperties properties, JwtDecoder jwtDecoder) {
        this.properties = properties;
        this.jwtDecoder = jwtDecoder;
    }

    public boolean isValid(String token) {
        Jwt jwt;
        try {
            jwt = jwtDecoder.decode(token);
        } catch (JwtException e) {
            log.warn("Invalid Play Pub/Sub push token", e);
            return false;
        }

        if (!VALID_ISSUERS.contains(jwt.getClaimAsString("iss"))) {
            return false;
        }
        List<String> audience = jwt.getAudience();
        if (audience == null || !audience.contains(properties.pubsubAudience())) {
            return false;
        }
        boolean emailVerified = Boolean.TRUE.equals(jwt.getClaimAsBoolean("email_verified"));
        return emailVerified && properties.pubsubServiceAccountEmail().equals(jwt.getClaimAsString("email"));
    }
}
