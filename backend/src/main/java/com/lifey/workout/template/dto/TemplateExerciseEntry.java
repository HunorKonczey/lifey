package com.lifey.workout.template.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record TemplateExerciseEntry(
        @NotNull Long exerciseId,
        @Positive Integer targetSets
) {
}
