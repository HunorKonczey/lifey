package com.lifey.workout.template.dto;

import java.time.Instant;
import java.util.List;

public record WorkoutTemplateResponse(
        Long id,
        String name,
        List<TemplateExerciseEntry> exercises,
        Instant updatedAt,
        Instant deletedAt
) {
}
