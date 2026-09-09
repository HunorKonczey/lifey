package com.lifey.billing.service;

import com.lifey.billing.dto.EntitlementResponse;
import com.lifey.billing.dto.StorePurchaseRequest;

/**
 * The store adapter — verifies an iOS/Android purchase and links it to the
 * calling user (docs/landing_page/64-billing-backend-plan.md §6).
 */
public interface StoreBillingService {

    /**
     * @return the caller's freshly resolved entitlement, reflecting the just-linked purchase
     * @throws com.lifey.billing.exception.InvalidReceiptException        if the purchase token could not be verified
     * @throws com.lifey.billing.exception.SubscriptionAlreadyLinkedException if it's already linked to a different account
     */
    EntitlementResponse verifyPurchase(Long userId, StorePurchaseRequest request);
}
