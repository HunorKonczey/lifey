package com.lifey.workout.session.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/**
 * One exercise planned for a session, with the number of sets it plans for —
 * see {@code WorkoutSessionRequest.plannedExercises}.
 *
 * <p>{@code targetSets} is optional: an exercise added ad hoc mid-session has
 * no plan, which is a different thing from planning zero sets.
 *
 * <p>{@code note} is the user's free-text comment on this exercise in this
 * session (LIF-224) — e.g. a machine setting. The mobile client pre-fills it
 * from the exercise's previous note, so each session keeps its own copy. A
 * blank note is stored as null.
 */
public record PlannedExerciseRequest(

        @NotNull
        Long exerciseId,

        @Positive
        Integer targetSets,

        @Size(max = MAX_NOTE_LENGTH)
        String note
) {

    public static final int MAX_NOTE_LENGTH = 1000;

    /** Shorthand for the callers (the fallback path, tests) that carry no note. */
    public PlannedExerciseRequest(Long exerciseId, Integer targetSets) {
        this(exerciseId, targetSets, null);
    }
}
