package com.lifey.trainer.dto;

import java.time.LocalDate;
import java.time.LocalTime;

/**
 * A scheduled occurrence for the trainer calendar (docs/personal_trainer/
 * 12-edzo-naptar-terv.md) — {@link ScheduledSessionResponse} plus the client
 * identity, since the calendar aggregates across every active client.
 */
public record TrainerCalendarSessionResponse(
        Long sessionId,
        Long clientId,
        String clientEmail,
        LocalDate scheduledFor,
        LocalTime scheduledTime,
        String templateName,
        OccurrenceStatus status,
        Long scheduleId,
        /* Set instead of scheduleId when this occurrence came from a multi-week program assignment. */
        Long programAssignmentId,
        /* Snapshot name of the program, for the calendar peek — null unless programAssignmentId is set. */
        String programName
) {
}
