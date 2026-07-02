package com.lifey.auth.exception;

/**
 * Thrown when a provider reports an unverified email for a login that would
 * otherwise auto-link to an existing account by email — auto-linking on an
 * unverified email is an account-takeover vector, so it's rejected instead.
 */
public class UnverifiedEmailException extends RuntimeException {

    public UnverifiedEmailException(String message) {
        super(message);
    }
}
