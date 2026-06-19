package com.lifey.workout.session.dto;

/** A planned exercise for a session — see {@code WorkoutSessionResponse.exercises}. */
public record ExerciseSummary(
        Long exerciseId,
        String exerciseName
) {
}
