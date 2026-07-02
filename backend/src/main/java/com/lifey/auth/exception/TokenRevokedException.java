package com.lifey.auth.exception;

/**
 * Thrown when a refresh token has already been revoked — either by an explicit
 * logout, or because rotation already consumed it once. Reuse of a rotated-out
 * refresh token is treated as a signal the token may have been stolen.
 */
public class TokenRevokedException extends RuntimeException {

    public TokenRevokedException(String message) {
        super(message);
    }
}
