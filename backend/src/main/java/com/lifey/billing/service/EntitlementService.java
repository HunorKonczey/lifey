package com.lifey.billing.service;

import com.lifey.billing.dto.EntitlementResponse;

/**
 * The only place the resolution rules in
 * docs/landing_page/63-monetization-strategy-plan.md §3 exist
 * (docs/landing_page/64-billing-backend-plan.md D-B3). No controller, no
 * other service, and no client re-derives them.
 */
public interface EntitlementService {

    /**
     * Never throws for a business reason: an unknown or entitlement-less user
     * resolves to a well-formed {@code FREE} response, and a downstream
     * failure fails open with {@code degraded = true} rather than
     * propagating (64 §3.1).
     */
    EntitlementResponse resolve(Long userId);
}
