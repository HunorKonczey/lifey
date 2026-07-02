package com.lifey.workout.session.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;

import java.time.Instant;

/**
 * {@code reps}/{@code weight} are intentionally unvalidated here: an incomplete
 * set (e.g. a plan row marked done before its reps were filled in) is a normal
 * client-side transient state, not a malformed request. {@link
 * com.lifey.workout.session.service.WorkoutSessionServiceImpl} silently drops
 * such rows instead of rejecting the whole request.
 */
public record ExerciseSetRequest(

        @NotNull
        Long exerciseId,

        Integer reps,

        Double weight,

        @NotNull
        @PastOrPresent
        Instant performedAt
) {
}
