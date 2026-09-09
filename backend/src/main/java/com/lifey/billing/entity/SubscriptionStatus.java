package com.lifey.billing.entity;

/**
 * Lifecycle of a {@link Subscription} row — see
 * docs/landing_page/64-billing-backend-plan.md §4.4 for what each status
 * allows a trainer to do.
 */
public enum SubscriptionStatus {
    TRIALING,
    ACTIVE,
    PAST_DUE,
    CANCELED,
    EXPIRED,
    REFUNDED
}
