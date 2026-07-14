package com.lifey.trainer.dto;

import java.time.LocalDate;
import java.time.LocalTime;

public record ScheduledSessionResponse(
        Long sessionId,
        LocalDate scheduledFor,
        LocalTime scheduledTime,
        String templateName,
        OccurrenceStatus status,
        Long scheduleId,
        /* Set instead of scheduleId when this occurrence came from a multi-week program assignment. */
        Long programAssignmentId
) {
}
