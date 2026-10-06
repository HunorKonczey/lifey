package com.lifey.nutrition.openfoodfacts.exception;

/**
 * OpenFoodFacts could not answer a search: timeout, connection failure, a 5xx or
 * an unreadable body. Distinct from "found nothing" (an empty list) on purpose —
 * the name search must not treat a failed Hungarian call as an empty one and fall
 * back to English (docs/84 D4).
 */
public class OffUnavailableException extends RuntimeException {

    public OffUnavailableException(String message) {
        super(message);
    }

    public OffUnavailableException(String message, Throwable cause) {
        super(message, cause);
    }
}
