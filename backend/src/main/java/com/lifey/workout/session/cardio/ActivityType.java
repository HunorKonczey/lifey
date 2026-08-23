package com.lifey.workout.session.cardio;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * The concrete cardio/sport activity a {@link com.lifey.workout.session.WorkoutSession}
 * of {@link com.lifey.workout.session.SessionKind#CARDIO} was logged as. Each
 * value belongs to exactly one {@link ActivityFamily}, which is what actually
 * drives metrics and UI layout — see docs/cardio/51-cardio-overview-plan.md §1
 * and docs/cardio/52-cardio-domain-backend-plan.md §1.
 */
@Getter
@AllArgsConstructor
public enum ActivityType {
    RUNNING(ActivityFamily.DISTANCE),
    WALKING(ActivityFamily.DISTANCE),
    HIKING(ActivityFamily.DISTANCE),
    CYCLING(ActivityFamily.DISTANCE),
    INDOOR_BIKE(ActivityFamily.MACHINE),
    BASKETBALL(ActivityFamily.GAME),
    FOOTBALL(ActivityFamily.GAME),

    /**
     * Escape hatch for an activity that doesn't have a dedicated type yet —
     * treated as {@link ActivityFamily#GAME} (time + heart rate + calories,
     * the metric set that fits any activity). See doc 52 D-C1.4.
     */
    OTHER_CARDIO(ActivityFamily.GAME);

    private final ActivityFamily family;
}
