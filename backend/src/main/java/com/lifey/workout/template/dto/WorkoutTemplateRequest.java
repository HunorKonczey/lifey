package com.lifey.workout.template.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record WorkoutTemplateRequest(

        @NotBlank
        String name,

        @NotEmpty
        List<@Valid TemplateExerciseEntry> exercises
) {
}
