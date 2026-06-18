package com.lifey.workout.template.dto;

import java.util.List;

public record WorkoutTemplateRequest(
        String name,
        List<Long> exerciseIds
) {
}
