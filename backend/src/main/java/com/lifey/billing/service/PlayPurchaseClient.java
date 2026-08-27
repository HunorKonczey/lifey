package com.lifey.billing.service;

import com.google.api.services.androidpublisher.model.SubscriptionPurchaseV2;

import java.io.IOException;

/**
 * A thin, mockable seam over the generated {@code AndroidPublisher} client
 * (docs/landing_page/64-billing-backend-plan.md §6.1) — unlike Apple's
 * StoreKit library, Google's generated client has no clean verifier object
 * to inject directly, so this interface is that seam.
 */
public interface PlayPurchaseClient {

    /** {@code purchases.subscriptionsv2.get} — the only verification a Play purchase gets; there is no local check. */
    SubscriptionPurchaseV2 getSubscription(String packageName, String purchaseToken) throws IOException;

    /**
     * An unacknowledged Play purchase is auto-refunded after 3 days (64 §6.1) —
     * a silent revenue loss, so callers must not swallow a failure here the
     * way {@code StoreBillingServiceImpl} swallows Apple's confirmation step.
     */
    void acknowledge(String packageName, String productId, String purchaseToken) throws IOException;
}
