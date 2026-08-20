package com.lifey.workout.session.dto;

import com.lifey.workout.session.cardio.IntervalIntensity;
import com.lifey.workout.session.cardio.SplitType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

/**
 * One section of a cardio session — a per-km/lap split or an executed
 * interval section, computed client-side (docs/cardio/52 §2.3, docs/cardio/60
 * D-C7.1). The server never derives these. A session's {@code splits} list is
 * replaced in full on every create/update, matching {@code
 * ExerciseSetRequest}'s replace-the-whole-list model but for a coarser unit.
 */
public record CardioSplitRequest(

        /* 0-based position within the session's split list. */
        @NotNull
        @PositiveOrZero
        Integer splitIndex,

        /*
         * DISTANCE (the default, and what a client that predates intervals
         * sends: absent means DISTANCE) or INTERVAL.
         */
        SplitType splitType,

        /*
         * Usually exactly 1000 (one km); the last split of a run is shorter.
         * Required for a DISTANCE split — cross-field, so the service checks
         * it (see InvalidCardioRequestException), not this annotation set.
         * Null for an INTERVAL section on a machine that reports no distance.
         */
        @PositiveOrZero
        Double distanceMeters,

        @NotNull
        @PositiveOrZero
        Integer durationSeconds,

        /* Net elevation change over the split; null when no altitude data was available. */
        Double elevationDeltaM,

        @PositiveOrZero
        Double avgHeartRate,

        /* Average power over the section; null without a watt-reporting machine. */
        @PositiveOrZero
        Double avgWatts,

        /*
         * The target effort the section was run at — INTERVAL only; the
         * service rejects it on a DISTANCE split.
         */
        IntervalIntensity intensity
) {
}
