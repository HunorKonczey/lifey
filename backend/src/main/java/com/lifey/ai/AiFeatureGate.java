package com.lifey.ai;

/**
 * The one place that decides whether a user may make an AI call right now
 * (docs/23-ai-calorie-estimation-plan.md "Subscription gating"). Called
 * <em>before</em> the model call; the usage counter is only incremented by the
 * caller <em>after</em> a successful one, so a failed call never burns a credit
 * (docs/landing_page/64-billing-backend-plan.md §3.4).
 */
public interface AiFeatureGate {

    /**
     * @throws com.lifey.ai.exception.AiCreditsExhaustedException when this
     * month's allowance for the user's plan is used up
     */
    void checkMealEstimation(Long userId);
}
