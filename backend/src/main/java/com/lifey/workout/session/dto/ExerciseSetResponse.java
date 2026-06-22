package com.lifey.workout.session.dto;

import java.time.Instant;

public record ExerciseSetResponse(
        Long exerciseId,
        String exerciseName,
        Integer reps,
        Double weight,
        Instant performedAt
) {
}
