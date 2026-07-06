package com.lifey.trainer.exception;

/**
 * The requesting trainer has no ACTIVE relationship with the target user —
 * used both to guard the revoke endpoint and, going forward, every
 * client-data-read endpoint (see TrainerAccessService#requireActiveClient).
 */
public class NotYourClientException extends RuntimeException {

    public NotYourClientException(String message) {
        super(message);
    }
}
