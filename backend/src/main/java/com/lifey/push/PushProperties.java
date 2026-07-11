package com.lifey.push;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Bound from {@code lifey.push.apns.*} (see application.yml). {@code enabled}
 * gates whether {@code ApnsPushSender} is created at all — off by default so
 * local dev and tests never need a real APNs key. {@code keyPath} is a
 * {@code .p8} token-auth key (no cert renewal); {@code sandbox} selects the
 * development vs. production APNs host.
 */
@ConfigurationProperties(prefix = "lifey.push.apns")
public record PushProperties(
        boolean enabled,
        String keyPath,
        String keyId,
        String teamId,
        String bundleId,
        boolean sandbox
) {
}
