package com.lifey.auth;

/**
 * The signature verified but the token is past its expiry. Reported separately
 * from {@link InvalidTokenException} because the client's reaction differs: this
 * one means "refresh at lifey-api and retry", not "sign in again" (§7.2).
 */
public class TokenExpiredException extends RuntimeException {

    public TokenExpiredException(String message) {
        super(message);
    }
}
