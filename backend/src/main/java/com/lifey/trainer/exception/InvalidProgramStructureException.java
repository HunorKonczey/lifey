package com.lifey.trainer.exception;

/**
 * A program's slot grid is malformed: a slot's week number exceeds
 * {@code weeksCount}, two slots share the same (week, day), or a slot
 * references a template the trainer doesn't own or has deleted.
 */
public class InvalidProgramStructureException extends RuntimeException {

    public InvalidProgramStructureException(String message) {
        super(message);
    }
}
