package com.lifey.workout.session.cardio.interval.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * Create/update payload for a reusable interval plan (docs/cardio/60 C7.2).
 * The step list is replaced in full on every update, same model as
 * {@code WorkoutTemplateRequest}'s exercises — the editor always sends the
 * complete plan it currently shows.
 */
public record CardioIntervalPlanRequest(

        @NotBlank
        @Size(max = 120)
        String name,

        @NotEmpty
        List<@Valid IntervalStepEntry> steps
) {
}
