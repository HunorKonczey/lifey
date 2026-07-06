package com.lifey.trainer.exception;

/** A schedule's start date is in the past. */
public class ScheduleInPastException extends RuntimeException {

    public ScheduleInPastException(String message) {
        super(message);
    }
}
