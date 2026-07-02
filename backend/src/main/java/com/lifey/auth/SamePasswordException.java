package com.lifey.auth;

/** Thrown by change-password when {@code newPassword} equals the current password. */
public class SamePasswordException extends RuntimeException {

    public SamePasswordException(String message) {
        super(message);
    }
}
