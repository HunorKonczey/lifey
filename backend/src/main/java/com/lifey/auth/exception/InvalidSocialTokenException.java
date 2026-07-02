package com.lifey.auth.exception;

/**
 * Thrown when a provider ID token fails signature, issuer, audience, or claim checks.
 */
public class InvalidSocialTokenException extends RuntimeException {

    public InvalidSocialTokenException(String message) {
        super(message);
    }
}
