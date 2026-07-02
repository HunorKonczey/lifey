package com.lifey.userdetails;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * Standard Katch activity multipliers applied to BMR to derive TDEE — see
 * docs/21-onboarding-user-details-plan.md "Derived output" section.
 */
@AllArgsConstructor
@Getter
public enum ActivityLevel {
    SEDENTARY(1.2),
    LIGHT(1.375),
    MODERATE(1.55),
    ACTIVE(1.725),
    VERY_ACTIVE(1.9);

    private final double tdeeMultiplier;
}
