package com.lifey.trainer.exception;

/** A schedule spans more than 3 months, or would materialize more occurrences than the sanity cap allows. */
public class ScheduleHorizonExceededException extends RuntimeException {

    public ScheduleHorizonExceededException(String message) {
        super(message);
    }
}
