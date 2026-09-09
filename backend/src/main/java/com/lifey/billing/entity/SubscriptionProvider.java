package com.lifey.billing.entity;

/**
 * Who is the source of truth for a {@link Subscription} row — see
 * docs/landing_page/64-billing-backend-plan.md D-B1.
 */
public enum SubscriptionProvider {
    STRIPE,
    APP_STORE,
    PLAY_STORE,
    COMP
}
