package com.lifey.common.exception;

/**
 * The text a client wants to search for is not searchable: too short, or nothing but punctuation. A client
 * mistake (HTTP 400), not an empty result — the clients are meant not to send such a request at all
 * (docs/84: at least 3 characters before the OpenFoodFacts name search runs).
 */
public class InvalidSearchQueryException extends RuntimeException {

    public InvalidSearchQueryException(String message) {
        super(message);
    }
}
