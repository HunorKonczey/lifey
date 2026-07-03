package com.lifey.trainer.exception;

/** No registered user matches the exact email address a trainer tried to invite. */
public class UserNotFoundForInviteException extends RuntimeException {

    public UserNotFoundForInviteException(String message) {
        super(message);
    }
}
