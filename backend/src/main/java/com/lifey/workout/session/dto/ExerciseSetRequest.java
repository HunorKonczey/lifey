package com.lifey.workout.session.dto;

public record ExerciseSetRequest(
        Long exerciseId,
        Integer reps,
        Double weight
) {
}
