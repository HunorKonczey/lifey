package com.lifey.billing.exception;

/** Wraps a checked {@code com.stripe.exception.StripeException} from the Stripe SDK boundary. */
public class StripeApiException extends RuntimeException {

    public StripeApiException(String message, Throwable cause) {
        super(message, cause);
    }
}
