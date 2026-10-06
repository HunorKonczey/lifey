package com.lifey.nutrition.openfoodfacts.exception;

/**
 * OpenFoodFacts refused a search because a rate limit was hit: HTTP 429, or 503,
 * which is what OFF returns when its global limits are exceeded (docs/84 spike).
 * Kept separate from {@link OffUnavailableException} so the caller can tell the
 * user "too many searches" instead of "not answering".
 */
public class OffRateLimitedException extends RuntimeException {

    public OffRateLimitedException(String message) {
        super(message);
    }
}
