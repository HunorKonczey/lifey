package com.lifey.billing.dto;

import java.time.Instant;

/**
 * The one object a client ever asks for — never a list of feature booleans it
 * has to interpret itself (docs/landing_page/64-billing-backend-plan.md §3.2,
 * docs/landing_page/63-monetization-strategy-plan.md §3). {@code historyDays}
 * and {@code aiCreditsRemaining} are {@code null} to mean unlimited.
 */
public record EntitlementResponse(
        EntitlementTier tier,
        EntitlementSource source,
        boolean adsEnabled,
        Integer historyDays,
        Integer aiCreditsRemaining,
        TrainerEntitlement trainer,
        Instant expiresAt,
        Instant checkedAt,
        Instant graceUntil,
        boolean degraded
) {
}
