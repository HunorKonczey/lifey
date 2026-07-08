package com.lifey.trainer.dto;

import com.lifey.trainer.Recurrence;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

public record ScheduleRequest(

        @NotNull
        Long clientId,

        /* One of the trainer's own workout templates. */
        @NotNull
        Long templateId,

        @NotNull
        Recurrence recurrence,

        /* Required (and only used) for WEEKLY. */
        List<DayOfWeek> daysOfWeek,

        /* Optional wall-clock time, inherited by every occurrence. */
        LocalTime timeOfDay,

        @NotNull
        LocalDate startDate,

        /*
         * For ONCE this is ignored (start date is used for both) — still
         * required on the wire so the column, which is NOT NULL in the
         * database for every recurrence, always has a caller-supplied value.
         */
        @NotNull
        LocalDate endDate
) {
    public ScheduleRequest {
        if (daysOfWeek == null) {
            daysOfWeek = List.of();
        }
    }
}
