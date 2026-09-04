package com.lifey.billing.entity;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * Trainer pricing tiers, keyed by active client count — see
 * docs/landing_page/63-monetization-strategy-plan.md D-M2. Studio's "unlimited"
 * is a 100-client fair-use ceiling handled as a support conversation, not as
 * code, so it still needs a concrete number here.
 */
@AllArgsConstructor
@Getter
public enum TrainerPlan {
    STARTER(5),
    PRO(25),
    STUDIO(100);

    private final int maxClients;
}
