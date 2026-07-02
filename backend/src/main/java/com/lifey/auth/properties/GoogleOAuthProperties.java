package com.lifey.auth.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

/**
 * Bound from {@code lifey.oauth.google.client-ids} — the Android, iOS, and Web
 * OAuth client IDs are all accepted as valid audiences, since the same backend
 * verifies ID tokens minted for any of the three clients.
 */
@ConfigurationProperties(prefix = "lifey.oauth.google")
public record GoogleOAuthProperties(List<String> clientIds) {
}
