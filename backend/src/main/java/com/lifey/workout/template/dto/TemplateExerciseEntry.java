package com.lifey.workout.template.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

public record TemplateExerciseEntry(
        @NotNull Long exerciseId,
        @Positive Integer targetSets,
        /*
         * Repetitions per set (LIF-106). On a request, null means "leave what is stored" - the phone never sends it -
         * and 0 clears it; a response carries the stored value or null.
         */
        @PositiveOrZero @Max(1000) Integer targetReps
) {

    /** An entry without a repetition count - what the phone sends, and what a template without reps holds. */
    public TemplateExerciseEntry(Long exerciseId, Integer targetSets) {
        this(exerciseId, targetSets, null);
    }
}
