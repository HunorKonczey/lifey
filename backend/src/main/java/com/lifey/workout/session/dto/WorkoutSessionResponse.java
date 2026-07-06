package com.lifey.workout.session.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

public record WorkoutSessionResponse(
        Long id,
        Instant startedAt,
        Instant finishedAt,
        List<ExerciseSummary> exercises,
        List<ExerciseSetResponse> sets,
        Double activeCalories,
        Double averageHeartRate,
        String healthWorkoutId,
        Long templateId,
        String templateName,
        /* Trainer-scheduled day; null for a normal (client-started) session. */
        LocalDate scheduledFor,
        /* Optional wall-clock time inherited from the schedule; display/ordering only. */
        LocalTime scheduledTime,
        /* The originating workout_schedules row id, if any. */
        Long scheduleId,
        Instant updatedAt,
        Instant deletedAt
) {
}
