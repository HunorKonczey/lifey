package com.lifey.trainer.exception;

/** A WEEKLY schedule has no days of week selected, or none fall within its date range. */
public class EmptyRecurrenceException extends RuntimeException {

    public EmptyRecurrenceException(String message) {
        super(message);
    }
}
