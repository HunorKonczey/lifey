package com.lifey.trainer.exception;

/** A program assignment's start date is not a Monday, or is in the past. */
public class ProgramStartDateInvalidException extends RuntimeException {

    public ProgramStartDateInvalidException(String message) {
        super(message);
    }
}
