package com.lifey.chat.exception;

/**
 * Thrown when {@code lifey.chat.enabled} is off (503). Reads deliberately keep
 * working — the switch exists to stop new traffic during an incident, not to
 * hide history from users.
 */
public class ChatDisabledException extends RuntimeException {

    public ChatDisabledException(String message) {
        super(message);
    }
}
