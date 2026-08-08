package com.lifey.chat.exception;

/** Thrown when a user exceeds their send budget (429). */
public class ChatRateLimitedException extends RuntimeException {

    public ChatRateLimitedException(String message) {
        super(message);
    }
}
