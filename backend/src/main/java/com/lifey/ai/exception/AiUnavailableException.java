package com.lifey.ai.exception;

/**
 * 502 {@code AI_UNAVAILABLE} — the model call failed (rate limit, upstream
 * error, timeout, refusal, unparseable answer). The client shows "try again
 * later"; the cause is logged server-side and never sent to the client.
 */
public class AiUnavailableException extends RuntimeException {

    public static final String CODE = "AI_UNAVAILABLE";

    public AiUnavailableException(String detail, Throwable cause) {
        super(detail, cause);
    }

    public AiUnavailableException(String detail) {
        super(detail);
    }
}
