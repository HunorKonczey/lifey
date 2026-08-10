package com.lifey.workout.session.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

/**
 * One per-km/lap split, computed client-side (docs/cardio/52 §2.3) — the
 * server never derives these. A session's {@code splits} list is replaced in
 * full on every create/update, matching {@code ExerciseSetRequest}'s
 * replace-the-whole-list model but for a coarser unit.
 */
public record CardioSplitRequest(

        /* 0-based position within the session's split list. */
        @NotNull
        @PositiveOrZero
        Integer splitIndex,

        /* Usually exactly 1000 (one km); the last split of a run is shorter. */
        @NotNull
        @PositiveOrZero
        Double distanceMeters,

        @NotNull
        @PositiveOrZero
        Integer durationSeconds,

        /* Net elevation change over the split; null when no altitude data was available. */
        Double elevationDeltaM,

        @PositiveOrZero
        Double avgHeartRate
) {
}
