package com.lifey.trainer.exception;

/**
 * No program assignment with this id owned by the requesting trainer — used
 * for both "doesn't exist" and "belongs to a different trainer" (404 in
 * both cases, to avoid leaking whether the id exists at all).
 */
public class ProgramAssignmentNotFoundException extends RuntimeException {

    public ProgramAssignmentNotFoundException(String message) {
        super(message);
    }
}
