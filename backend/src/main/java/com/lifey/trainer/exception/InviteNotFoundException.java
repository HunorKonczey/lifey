package com.lifey.trainer.exception;

/**
 * No matching invite for this actor — covers both "never existed" and
 * "expired" (an expired PENDING invite is treated as gone, per
 * docs/personal_trainer/01-koncepcio-es-folyamatok.md: it disappears from
 * both the trainer's and the client's view).
 */
public class InviteNotFoundException extends RuntimeException {

    public InviteNotFoundException(String message) {
        super(message);
    }
}
