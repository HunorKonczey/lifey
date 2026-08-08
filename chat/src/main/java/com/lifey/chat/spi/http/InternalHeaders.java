package com.lifey.chat.spi.http;

/**
 * Names shared with {@code lifey-api}'s side of the internal API (§5.5).
 * A constant rather than a literal at each call site: a typo in a header name
 * is a 401 that looks like a wrong secret.
 */
public final class InternalHeaders {

    public static final String TOKEN_HEADER = "X-Lifey-Internal";

    private InternalHeaders() {
    }
}
