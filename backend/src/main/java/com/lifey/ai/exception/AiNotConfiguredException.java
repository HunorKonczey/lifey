package com.lifey.ai.exception;

/**
 * 503 {@code AI_NOT_CONFIGURED} — no Anthropic API key is set in this
 * environment ({@code ANTHROPIC_API_KEY}). A deployment problem, not a client
 * one.
 */
public class AiNotConfiguredException extends RuntimeException {

    public static final String CODE = "AI_NOT_CONFIGURED";

    public AiNotConfiguredException() {
        super(CODE);
    }
}
