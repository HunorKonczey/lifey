package com.lifey.workout.session.dto;

/**
 * A planned exercise for a session — see {@code WorkoutSessionResponse.exercises}.
 */
public record ExerciseSummary(
        Long exerciseId,
        String exerciseName,

        /*
         * How many sets the session plans for this exercise, or null when it has
         * no plan (added ad hoc, or written before the column existed — V63).
         * The client rebuilds its still-blank set rows from this, so dropping it
         * from the response is what used to make them disappear.
         */
        Integer targetSets
) {
}
