package com.lifey.trainer.exception;

/**
 * No schedule/scheduled-session with this id owned by the requesting trainer —
 * used for both "doesn't exist" and "belongs to a different trainer" (404 in
 * both cases, to avoid leaking whether the id exists at all).
 */
public class ScheduleNotFoundException extends RuntimeException {

    public ScheduleNotFoundException(String message) {
        super(message);
    }
}
