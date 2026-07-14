package com.lifey.auth.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

import java.util.List;

/**
 * Bound from {@code lifey.oauth.google.*}. {@code clientIds}: the Android,
 * iOS, and Web OAuth client IDs are all accepted as valid audiences, since
 * the same backend verifies ID tokens minted for any of the three clients.
 * {@code jwksUri}: Google's published JWKS endpoint — overridable per
 * environment (e.g. pointed at a local mock JWKS server in tests) rather
 * than hardcoded, defaulting to the real endpoint everywhere it isn't set.
 */
@ConfigurationProperties(prefix = "lifey.oauth.google")
public record GoogleOAuthProperties(
        List<String> clientIds,
        @DefaultValue("https://www.googleapis.com/oauth2/v3/certs") String jwksUri
) {
}
