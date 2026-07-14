package com.lifey.trainer.dto;

import java.time.DayOfWeek;
import java.time.LocalTime;

public record ProgramWorkoutResponse(
        Long id,
        int weekNumber,
        DayOfWeek dayOfWeek,
        Long templateId,
        /* Resolved live, so a rename of the template shows up here immediately. */
        String templateName,
        LocalTime timeOfDay,
        String note
) {
}
