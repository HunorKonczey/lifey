package com.lifey.billing;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Bound from {@code lifey.billing.*} (see application.yml). {@code enabled}
 * defaults to {@code false} — with it off, {@code EntitlementService} returns
 * an open PRO/COMP entitlement for every user and every seat check passes, so
 * this feature is safe to deploy before any client understands it
 * (docs/landing_page/64-billing-backend-plan.md §1 point 6, §14 risk 1).
 *
 * <p>{@code freeHistoryDays} and {@code freeAiCreditsPerMonth} are display/
 * enforcement limits read by the resolver, never constants in a client — so
 * changing them is a config change, not a store release (§3.3).
 *
 * <p>{@code reconciliationBatchSize} caps how many non-terminal {@code
 * subscription} rows {@code BillingReconciliationJob} re-checks against the
 * provider per run (§7) — a large account base must not blow Stripe/Apple/
 * Google's rate limits every night.
 */
@ConfigurationProperties(prefix = "lifey.billing")
public record BillingProperties(
        boolean enabled,
        int freeHistoryDays,
        int freeAiCreditsPerMonth,
        int offlineGraceDays,
        int reconciliationBatchSize
) {
}
