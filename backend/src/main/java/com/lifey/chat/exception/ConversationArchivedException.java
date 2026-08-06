package com.lifey.chat.exception;

/** Thrown when writing to a thread whose trainer-client relationship has ended (409). */
public class ConversationArchivedException extends RuntimeException {

    public ConversationArchivedException(String message) {
        super(message);
    }
}
