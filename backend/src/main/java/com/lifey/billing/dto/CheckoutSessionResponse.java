package com.lifey.billing.dto;

/** The Stripe Checkout URL to redirect the browser to. */
public record CheckoutSessionResponse(String url) {
}
