package com.lifey.trainer.request.exception;

/** A decision (approve/reject) was attempted on a trainer request that isn't {@code PENDING} any more. */
public class TrainerRequestAlreadyDecidedException extends RuntimeException {

    public TrainerRequestAlreadyDecidedException(String message) {
        super(message);
    }
}
