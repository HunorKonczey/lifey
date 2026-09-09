package com.lifey.billing.service;

/**
 * The per-user, per-calendar-month AI call counter (docs/landing_page/64-billing-backend-plan.md
 * §3.4, 63 D-M5).
 */
public interface AiUsageCounterService {

    /** How many AI calls this user has already made this calendar month. */
    int usedThisMonth(Long userId);

    /**
     * Records one AI call for this user against the current calendar month.
     * Callers must only invoke this after a *successful* call — a failed LLM
     * call must not burn a credit (§3.4), and this class has no way to know
     * whether the call it's being told about actually succeeded.
     */
    void recordUsage(Long userId);
}
