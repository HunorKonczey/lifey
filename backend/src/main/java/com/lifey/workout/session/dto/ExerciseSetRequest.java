package com.lifey.workout.session.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

import java.time.Instant;

public record ExerciseSetRequest(

        @NotNull
        Long exerciseId,

        @NotNull
        @Positive
        Integer reps,

        @NotNull
        @PositiveOrZero
        Double weight,

        @NotNull
        @PastOrPresent
        Instant performedAt
) {
}
