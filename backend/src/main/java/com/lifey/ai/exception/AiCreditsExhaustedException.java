package com.lifey.ai.exception;

/**
 * 402 {@code AI_CREDITS_EXHAUSTED} — the user's plan includes the AI feature
 * and this month's allowance is used up (docs/landing_page/64-billing-backend-plan.md
 * §3.4). The mobile app routes a 402 to the paywall with the {@code aiCredits}
 * trigger.
 */
public class AiCreditsExhaustedException extends RuntimeException {

    public static final String CODE = "AI_CREDITS_EXHAUSTED";

    public AiCreditsExhaustedException() {
        super(CODE);
    }
}
