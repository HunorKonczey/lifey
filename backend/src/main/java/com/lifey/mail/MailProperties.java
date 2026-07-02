package com.lifey.mail;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Bound from {@code app.mail.*} (see application.yml). {@code enabled} gates
 * actually sending through SMTP — off by default so local dev and tests never
 * need real Gmail credentials; when off, the sender logs instead of sending.
 */
@ConfigurationProperties(prefix = "lifey.mail")
public record MailProperties(
        String from,
        boolean enabled
) {
}
