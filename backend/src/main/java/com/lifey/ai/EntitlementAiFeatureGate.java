package com.lifey.ai;

import com.lifey.ai.exception.AiCreditsExhaustedException;
import com.lifey.billing.BillingProperties;
import com.lifey.billing.dto.EntitlementTier;
import com.lifey.billing.service.AiUsageCounterService;
import com.lifey.billing.service.EntitlementService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * Limits AI calls per calendar month by plan: Free gets {@code
 * freeAiCreditsPerMonth} (63 D-M5), Pro gets the fair-use ceiling {@code
 * proAiFairUsePerMonth} (D-M5 note 2) — the entitlement reports Pro as
 * unlimited, and enforcing the ceiling is deliberately this gate's job, not the
 * resolver's (docs/23 "Pro is not unlimited-unlimited").
 *
 * <p>The tier comes from {@link EntitlementService}, so the billing rollback
 * switch and its fail-open behaviour carry over unchanged: with billing
 * disabled or degraded everyone resolves to Pro and only the ceiling applies.
 *
 * <p>Check-then-act: two requests racing on the last credit can both pass. That
 * overshoots by at most the number of concurrent requests, which is cheaper
 * than serializing every AI call on a row lock.
 */
@Component
@RequiredArgsConstructor
class EntitlementAiFeatureGate implements AiFeatureGate {

    private final EntitlementService entitlementService;
    private final AiUsageCounterService aiUsageCounterService;
    private final BillingProperties billingProperties;

    @Override
    public void checkMealEstimation(Long userId) {
        int limit = entitlementService.resolve(userId).tier() == EntitlementTier.PRO
                ? billingProperties.proAiFairUsePerMonth()
                : billingProperties.freeAiCreditsPerMonth();
        if (aiUsageCounterService.usedThisMonth(userId) >= limit) {
            throw new AiCreditsExhaustedException();
        }
    }
}
