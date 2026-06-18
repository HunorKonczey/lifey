package com.lifey.workout.session.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

public record ExerciseSetRequest(

        @NotNull
        Long exerciseId,

        @NotNull
        @Positive
        Integer reps,

        @NotNull
        @PositiveOrZero
        Double weight
) {
}
