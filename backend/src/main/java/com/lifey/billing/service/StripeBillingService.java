package com.lifey.billing.service;

import com.lifey.billing.dto.BillingInterval;
import com.lifey.billing.entity.TrainerPlan;

/**
 * The Stripe adapter (docs/landing_page/64-billing-backend-plan.md §5). Both
 * methods only create a session and hand back its URL — neither one writes
 * {@code subscription}; entitlement changes exclusively on the webhook
 * (`64` Prompt 5, D-B5), which may land after the browser redirect.
 */
public interface StripeBillingService {

    /** {@code client_reference_id} is the trainer's own user id — that is how the webhook finds them back (§11.1). */
    String createCheckoutSession(Long trainerId, TrainerPlan plan, BillingInterval interval);

    /** @throws com.lifey.common.exception.ResourceNotFoundException if the trainer has no linked Stripe customer yet. */
    String createPortalSession(Long trainerId);
}
