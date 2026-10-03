package com.lifey.chat.exception;

/**
 * A card that passed bean validation but breaks a cross-field rule — the wrong
 * sub-object for its kind, a time in the future, a blank name (400). Handled as
 * an {@link InvalidMessageBodyException}: to the client it is the same kind of
 * mistake, a message that cannot be stored as sent.
 */
public class InvalidMessageCardException extends InvalidMessageBodyException {

    public InvalidMessageCardException(String message) {
        super(message);
    }
}
