package com.lifey.auth;

/** Malformed, wrongly signed, or issued by someone other than lifey-api. */
public class InvalidTokenException extends RuntimeException {

    public InvalidTokenException(String message) {
        super(message);
    }
}
