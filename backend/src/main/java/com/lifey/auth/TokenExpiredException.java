package com.lifey.auth;

/** Thrown when an access or refresh token is syntactically valid but past its expiry. */
public class TokenExpiredException extends RuntimeException {

    public TokenExpiredException(String message) {
        super(message);
    }
}
