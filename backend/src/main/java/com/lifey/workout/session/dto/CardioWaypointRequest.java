package com.lifey.workout.session.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

/**
 * One point marked along a hike's route, computed client-side (docs/cardio/60
 * C8.1) — the server never derives these. A session's {@code waypoints} list
 * is replaced in full on every create/update, matching {@code
 * CardioSplitRequest}'s replace-the-whole-list model.
 */
public record CardioWaypointRequest(

        /* 0-based position in the order the waypoints were marked. */
        @NotNull
        @PositiveOrZero
        Integer waypointIndex,

        @NotNull
        Double latitude,

        @NotNull
        Double longitude,

        /* Null when the fix at the moment of marking carried no altitude. */
        Double altitudeMeters,

        /* Always null in V1 (docs/cardio/60 Q-D5) — no input field for it yet. */
        String label
) {
}
