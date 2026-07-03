package com.lifey.trainer.exception;

/** A trainer tried to invite themselves as a client. */
public class SelfInviteException extends RuntimeException {

    public SelfInviteException(String message) {
        super(message);
    }
}
