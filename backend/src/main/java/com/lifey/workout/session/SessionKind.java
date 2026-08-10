package com.lifey.workout.session;

/**
 * Discriminates a {@link WorkoutSession} between the original set-based
 * (strength) workout and a cardio/sport session — see
 * docs/cardio/52-cardio-domain-backend-plan.md §1.
 */
public enum SessionKind {
    STRENGTH,
    CARDIO
}
