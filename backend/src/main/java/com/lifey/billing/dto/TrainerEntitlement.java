package com.lifey.billing.dto;

import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.entity.TrainerPlan;

import java.time.Instant;

/**
 * Present only when the caller holds {@code ROLE_TRAINER} — their own Stripe
 * subscription state, independent of the entitlement resolved for {@code
 * tier}/{@code source} above (64 §3.2). {@code plan}/{@code status} are null
 * and {@code maxClients} is unlimited-in-effect when the trainer has no
 * subscription row yet (trial not started, or billing disabled).
 */
public record TrainerEntitlement(
        TrainerPlan plan,
        SubscriptionStatus status,
        Integer maxClients,
        int activeClients,
        Instant trialEndsAt
) {
}
