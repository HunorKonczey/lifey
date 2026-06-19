package com.lifey.auth;

/** Thrown for a malformed, unsigned, or otherwise structurally invalid token. */
public class InvalidTokenException extends RuntimeException {

    public InvalidTokenException(String message) {
        super(message);
    }
}
