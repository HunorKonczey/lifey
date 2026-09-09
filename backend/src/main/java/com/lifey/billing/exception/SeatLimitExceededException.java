package com.lifey.billing.exception;

/**
 * Thrown by {@code SeatLimitService#assertCanAcquireClient} — a trainer tried
 * to acquire a client (by invite or, from `64` Prompt 6, an accept) beyond
 * what their plan or billing state allows (docs/landing_page/64-billing-backend-plan.md §4.2).
 */
public class SeatLimitExceededException extends RuntimeException {

    public SeatLimitExceededException(String message) {
        super(message);
    }
}
