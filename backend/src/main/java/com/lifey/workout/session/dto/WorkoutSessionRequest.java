package com.lifey.workout.session.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.PositiveOrZero;

import java.time.Instant;
import java.util.List;

public record WorkoutSessionRequest(

        @NotNull
        @PastOrPresent
        Instant startedAt,

        @PastOrPresent
        Instant finishedAt,

        /*
         * Exercises planned for this session (e.g. resolved client-side from a
         * template's exerciseIds). May be empty for a session started from scratch.
         */
        @NotNull
        List<Long> exerciseIds,

        /*
         * Sets actually logged so far. May be empty — a session can be started
         * with no sets recorded yet and filled in as the workout progresses.
         */
        @NotNull
        List<@Valid ExerciseSetRequest> sets,

        /* Active energy burned (kcal), imported from Apple Health. */
        @PositiveOrZero
        Double activeCalories,

        /* Average heart rate (bpm) over the workout, imported from Apple Health. */
        @PositiveOrZero
        Double averageHeartRate,

        /* HKWorkout UUID this session was paired with, if imported from Apple Health. */
        String healthWorkoutId
) {
}
