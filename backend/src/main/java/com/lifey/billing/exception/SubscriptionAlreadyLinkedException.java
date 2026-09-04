package com.lifey.billing.exception;

/**
 * A store purchase's identity (the Apple {@code originalTransactionId} / a
 * Play purchase token's linked subscription id, D-B6) is already linked to a
 * different account. 63 §7.7: a second redemption is a clean 409, never a
 * silently transferred entitlement.
 */
public class SubscriptionAlreadyLinkedException extends RuntimeException {

    public SubscriptionAlreadyLinkedException(String message) {
        super(message);
    }
}
