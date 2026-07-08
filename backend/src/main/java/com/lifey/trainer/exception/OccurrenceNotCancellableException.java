package com.lifey.trainer.exception;

/** The occurrence has already started, is in the past, or is already cancelled. */
public class OccurrenceNotCancellableException extends RuntimeException {

    public OccurrenceNotCancellableException(String message) {
        super(message);
    }
}
