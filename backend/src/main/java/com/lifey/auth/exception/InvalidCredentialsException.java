package com.lifey.auth.exception;

/**
 * Thrown when login credentials don't match (wrong email or password).
 */
public class InvalidCredentialsException extends RuntimeException {

    public InvalidCredentialsException(String message) {
        super(message);
    }
}
