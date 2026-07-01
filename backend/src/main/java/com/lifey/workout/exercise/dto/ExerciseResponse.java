package com.lifey.workout.exercise.dto;

import java.time.Instant;

public record ExerciseResponse(
        Long id,
        String name,
        String category,
        String equipment,
        Instant updatedAt,
        Instant deletedAt
) {
}
