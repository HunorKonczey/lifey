package com.lifey.workout.session.dto;

import com.lifey.workout.session.SessionKind;
import com.lifey.workout.session.cardio.ActivityType;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

public record WorkoutSessionResponse(
        Long id,
        Instant startedAt,
        Instant finishedAt,
        /* Empty, never null, for a CARDIO session (it has no exercises) — see docs/cardio/52 §3.3. */
        List<ExerciseSummary> exercises,
        /* Empty, never null, for a CARDIO session (it has no sets). */
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
        /* Difficulty rating (1-10, RPE-style), captured after finishing. Null if unrated. */
        Integer rpe,
        /* Optional free-text note captured alongside rpe. */
        String feedbackNote,
        /* The trainer's single editable comment on this session; null when uncommented. */
        String trainerComment,
        /* When trainerComment was last written; null when uncommented. */
        Instant trainerCommentAt,
        Instant updatedAt,
        Instant deletedAt,

        /* Never null — STRENGTH for every session predating cardio, and for every actual strength session. */
        SessionKind sessionKind,
        /* Non-null exactly when sessionKind is CARDIO. */
        ActivityType activityType,
        Integer movingSeconds,
        /* Non-null exactly when sessionKind is CARDIO and at least one metric was recorded. */
        CardioDetailsResponse cardio,
        /* Empty, never null, unless sessionKind is CARDIO and splits were recorded. */
        List<CardioSplitResponse> splits,
        /* Empty, never null, unless sessionKind is CARDIO and waypoints were marked. */
        List<CardioWaypointResponse> waypoints
) {
}
