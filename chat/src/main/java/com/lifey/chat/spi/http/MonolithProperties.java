package com.lifey.chat.spi.http;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

/**
 * How to reach {@code lifey-api} for the things it still owns (§6.1).
 *
 * @param baseUrl       the monolith's origin, no trailing slash. Empty disables
 *                      every outbound call — which is how a local chat-only run
 *                      works without a monolith next to it.
 * @param internalToken shared secret sent as {@code X-Lifey-Internal}. Must match
 *                      {@code LIFEY_INTERNAL_TOKEN} on the other side (§5.5).
 * @param connectTimeout kept short on purpose: a slow monolith must not hold a
 *                      chat request thread. The push is best-effort — the §5.4
 *                      reminder job is the safety net for anything dropped.
 */
@ConfigurationProperties(prefix = "lifey.monolith")
public record MonolithProperties(
        String baseUrl,
        String internalToken,
        Duration connectTimeout,
        Duration readTimeout
) {
    public boolean isConfigured() {
        return baseUrl != null && !baseUrl.isBlank();
    }
}
