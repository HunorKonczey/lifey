package com.lifey.workout.session.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/**
 * One exercise planned for a session, with the number of sets it plans for —
 * see {@code WorkoutSessionRequest.plannedExercises}.
 *
 * <p>{@code targetSets} is optional: an exercise added ad hoc mid-session has
 * no plan, which is a different thing from planning zero sets.
 */
public record PlannedExerciseRequest(

        @NotNull
        Long exerciseId,

        @Positive
        Integer targetSets
) {
}
