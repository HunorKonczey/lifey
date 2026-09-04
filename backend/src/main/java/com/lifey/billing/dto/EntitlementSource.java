package com.lifey.billing.dto;

/** How a {@link EntitlementResponse#tier()} of PRO was earned — 64 §3.2. */
public enum EntitlementSource {
    NONE,
    STRIPE,
    APP_STORE,
    PLAY_STORE,
    TRAINER_SPONSORED,
    TRAINER_TRIAL,
    COMP
}
