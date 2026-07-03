package com.lifey.trainer.exception;

/** Either the per-recipient 24h cooldown or the trainer's daily invite cap was hit. */
public class InviteRateLimitedException extends RuntimeException {

    public InviteRateLimitedException(String message) {
        super(message);
    }
}
