package com.lifey.workout.session.dto;

public record ExerciseSetResponse(
        Long exerciseId,
        String exerciseName,
        Integer reps,
        Double weight
) {
}
