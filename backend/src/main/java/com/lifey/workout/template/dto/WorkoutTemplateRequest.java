package com.lifey.workout.template.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.PositiveOrZero;

import java.util.List;

public record WorkoutTemplateRequest(

        @NotBlank
        String name,

        @NotEmpty
        List<@Valid TemplateExerciseEntry> exercises,

        /*
         * How long the workout takes, in minutes (LIF-106). Null means "leave what is stored" - the phone does not send
         * it - and 0 clears it.
         */
        @PositiveOrZero @Max(1000)
        Integer durationMinutes
) {

    /** A request without a duration - what the phone sends. */
    public WorkoutTemplateRequest(String name, List<TemplateExerciseEntry> exercises) {
        this(name, exercises, null);
    }
}
