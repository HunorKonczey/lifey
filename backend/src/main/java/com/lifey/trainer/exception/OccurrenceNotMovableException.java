package com.lifey.trainer.exception;

/** The occurrence has already started, is in the past, is cancelled — or the target day is not a valid one to move it to. */
public class OccurrenceNotMovableException extends RuntimeException {

    public OccurrenceNotMovableException(String message) {
        super(message);
    }
}
