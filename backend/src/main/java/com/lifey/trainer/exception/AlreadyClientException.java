package com.lifey.trainer.exception;

/** The trainer already has an active relationship with this user. */
public class AlreadyClientException extends RuntimeException {

    public AlreadyClientException(String message) {
        super(message);
    }
}
