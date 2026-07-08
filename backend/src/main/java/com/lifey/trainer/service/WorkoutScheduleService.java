package com.lifey.trainer.service;

import com.lifey.trainer.dto.ScheduleRequest;
import com.lifey.trainer.dto.ScheduleResponse;
import com.lifey.trainer.dto.ScheduleSummaryResponse;
import com.lifey.trainer.dto.ScheduledSessionResponse;
import com.lifey.trainer.dto.TrainerCalendarSessionResponse;

import java.time.LocalDate;
import java.util.List;

public interface WorkoutScheduleService {

    ScheduleResponse create(ScheduleRequest request);

    List<ScheduleSummaryResponse> findForClient(Long clientId);

    List<ScheduledSessionResponse> findScheduledSessions(Long clientId, LocalDate from, LocalDate to);

    /**
     * Every active client's scheduled occurrences in a date range, for the trainer
     * calendar (docs/personal_trainer/12-edzo-naptar-terv.md). {@code from}/{@code to}
     * must not span more than 62 days.
     */
    List<TrainerCalendarSessionResponse> findScheduledSessionsForTrainer(LocalDate from, LocalDate to);

    /** Cancels the schedule and soft-deletes its future, not-yet-started occurrences. */
    void cancelSchedule(Long scheduleId);

    /** Cancels a single future, not-yet-started occurrence. */
    void cancelOccurrence(Long sessionId);

    /**
     * Cancels every still-active schedule between this trainer and client — the
     * REVOKED disconnect hook (see {@code com.lifey.trainer.ScheduleCancellationListener}).
     */
    void cancelActiveSchedulesForPair(Long trainerId, Long clientId);
}
