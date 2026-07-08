package com.lifey.trainer.exception;

/** The trainer calendar's {@code from}/{@code to} range is invalid or spans more than 62 days. */
public class CalendarRangeExceededException extends RuntimeException {

    public CalendarRangeExceededException(String message) {
        super(message);
    }
}
