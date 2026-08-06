package com.lifey.chat;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Bound from {@code lifey.chat.*} (see application.yml).
 *
 * @param enabled            kill switch: when false, existing threads stay
 *                           readable but sending is rejected with 503 — the
 *                           incident-response lever from §8/I7
 * @param maxBodyLength      max characters per message, checked after trimming
 * @param defaultPageSize    page size when the caller doesn't ask for one
 * @param maxPageSize        upper bound a caller can ask for
 * @param rateLimitPerMinute per-user send budget, abuse protection (§7.2)
 * @param rateLimitPerDay    per-user daily send budget
 */
@ConfigurationProperties(prefix = "lifey.chat")
public record ChatProperties(
        boolean enabled,
        int maxBodyLength,
        int defaultPageSize,
        int maxPageSize,
        int rateLimitPerMinute,
        int rateLimitPerDay
) {
}
