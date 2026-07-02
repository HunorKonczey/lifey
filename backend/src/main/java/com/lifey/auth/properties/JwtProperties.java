package com.lifey.auth.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

/**
 * Bound from {@code lifey.jwt.*} (see application.yml). The secret and both TTLs
 * are environment-overridable so a deployment never ships the dev default secret.
 */
@ConfigurationProperties(prefix = "lifey.jwt")
public record JwtProperties(
        String secret,
        Duration accessTokenTtl,
        Duration refreshTokenTtl,
        String issuer
) {
}
