package com.lifey.trainer.service;

import com.lifey.trainer.dto.ScheduleRequest;
import com.lifey.trainer.dto.ScheduleResponse;
import com.lifey.trainer.dto.ScheduleSummaryResponse;
import com.lifey.trainer.dto.ScheduledSessionResponse;

import java.time.LocalDate;
import java.util.List;

public interface WorkoutScheduleService {

    ScheduleResponse create(ScheduleRequest request);

    List<ScheduleSummaryResponse> findForClient(Long clientId);

    List<ScheduledSessionResponse> findScheduledSessions(Long clientId, LocalDate from, LocalDate to);

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
