package com.lifey.auth;

/** Thrown by change-password when {@code currentPassword} doesn't match. */
public class IncorrectPasswordException extends RuntimeException {

    public IncorrectPasswordException(String message) {
        super(message);
    }
}
