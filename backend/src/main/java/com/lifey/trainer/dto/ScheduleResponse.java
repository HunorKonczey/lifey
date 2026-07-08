package com.lifey.trainer.dto;

import com.lifey.trainer.Recurrence;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

public record ScheduleResponse(
        Long id,
        Long clientId,
        Long templateId,
        String templateName,
        Recurrence recurrence,
        List<DayOfWeek> daysOfWeek,
        LocalTime timeOfDay,
        LocalDate startDate,
        LocalDate endDate,
        int occurrencesCreated
) {
}
