package com.lifey.mail;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Bound from {@code lifey.mail.*} (see application.yml). {@code enabled} gates
 * actually sending through the Resend API — off by default so local dev and
 * tests never need a real API key; when off, the sender logs instead of
 * sending.
 */
@ConfigurationProperties(prefix = "lifey.mail")
public record MailProperties(
        String from,
        boolean enabled,
        String resendApiKey
) {
}
