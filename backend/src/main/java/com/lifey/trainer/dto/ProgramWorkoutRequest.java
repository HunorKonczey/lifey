package com.lifey.trainer.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.DayOfWeek;
import java.time.LocalTime;

/** One week/day slot in a program's grid. */
public record ProgramWorkoutRequest(

        @NotNull
        @Min(1)
        Integer weekNumber,

        @NotNull
        DayOfWeek dayOfWeek,

        /* One of the trainer's own workout templates. */
        @NotNull
        Long templateId,

        /* Optional wall-clock time, inherited by the occurrence generated from this slot. */
        LocalTime timeOfDay,

        /* Optional trainer-facing progression note — not shown to the client. */
        @Size(max = 500)
        String note
) {
}
