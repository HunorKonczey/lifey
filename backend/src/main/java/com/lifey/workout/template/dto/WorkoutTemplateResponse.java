package com.lifey.workout.template.dto;

import java.util.List;

public record WorkoutTemplateResponse(
        Long id,
        String name,
        List<TemplateExerciseEntry> exercises
) {
}
