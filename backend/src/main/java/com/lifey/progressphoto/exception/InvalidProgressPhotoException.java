package com.lifey.progressphoto.exception;

/** A progress-photo upload whose metadata is unusable (e.g. a future date); maps to 400. */
public class InvalidProgressPhotoException extends RuntimeException {

    public InvalidProgressPhotoException(String message) {
        super(message);
    }
}
