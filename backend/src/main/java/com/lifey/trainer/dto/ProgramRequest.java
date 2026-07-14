package com.lifey.trainer.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

public record ProgramRequest(

        @NotBlank
        @Size(max = 120)
        String name,

        @NotNull
        @Min(1)
        @Max(12)
        Integer weeksCount,

        @NotEmpty
        List<@Valid ProgramWorkoutRequest> workouts
) {
}
