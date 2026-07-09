package com.lifey.workout.exercise.dto;

import com.lifey.workout.exercise.Equipment;
import com.lifey.workout.exercise.MuscleGroup;
import jakarta.validation.constraints.NotBlank;

public record ExerciseRequest(

        @NotBlank
        String name,

        MuscleGroup category,

        Equipment equipment,

        String description
) {
}
