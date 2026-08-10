package com.lifey.workout.session.cardio;

/**
 * The three metric/UI shapes a cardio {@link ActivityType} falls into — see
 * docs/cardio/51-cardio-overview-plan.md §1.1. Never persisted directly:
 * always derived from {@link ActivityType#getFamily()}.
 */
public enum ActivityFamily {
    /** Running, walking, hiking — distance, pace, elevation, GPS route. */
    DISTANCE,

    /** Indoor bike — cadence, power, resistance, no GPS. */
    MACHINE,

    /** Basketball, football — playing time vs. gross time, heart-rate zones. */
    GAME
}
