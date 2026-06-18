package com.lifey.workout.session.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;

import java.time.Instant;
import java.util.List;

public record WorkoutSessionRequest(

        @NotNull
        @PastOrPresent
        Instant startedAt,

        @PastOrPresent
        Instant finishedAt,

        @NotEmpty
        List<@Valid ExerciseSetRequest> sets
) {
}
