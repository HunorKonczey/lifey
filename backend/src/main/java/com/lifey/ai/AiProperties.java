package com.lifey.ai;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Bound from {@code lifey.ai.*} (see application.yml) — the Claude API
 * settings for the AI features (docs/23-ai-calorie-estimation-plan.md).
 *
 * <p>{@code apiKey} is an Anthropic Console key, held only here: the mobile app
 * never calls the model directly, the same rule as OpenFoodFacts. It may be
 * blank (local dev, CI), in which case no client is built and the AI endpoints
 * answer 503 rather than the app failing to start. {@code model} is config so
 * it can be swapped after comparing estimate quality and cost on real photos.
 */
@ConfigurationProperties(prefix = "lifey.ai")
public record AiProperties(
        String apiKey,
        String model,
        int timeoutSeconds
) {

    public boolean isConfigured() {
        return apiKey != null && !apiKey.isBlank();
    }
}
