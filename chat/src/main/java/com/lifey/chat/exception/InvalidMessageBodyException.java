package com.lifey.chat.exception;

/**
 * Thrown when a message body is blank after trimming or exceeds
 * {@code lifey.chat.max-body-length} (400). The length bound isn't a
 * bean-validation annotation because it is configurable.
 */
public class InvalidMessageBodyException extends RuntimeException {

    public InvalidMessageBodyException(String message) {
        super(message);
    }
}
