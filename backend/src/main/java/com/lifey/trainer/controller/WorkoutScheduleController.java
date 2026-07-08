package com.lifey.trainer.controller;

import com.lifey.trainer.dto.ScheduleRequest;
import com.lifey.trainer.dto.ScheduleResponse;
import com.lifey.trainer.dto.ScheduleSummaryResponse;
import com.lifey.trainer.dto.ScheduledSessionResponse;
import com.lifey.trainer.dto.TrainerCalendarSessionResponse;
import com.lifey.trainer.service.WorkoutScheduleService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@Tag(name = "Trainer Schedules", description = "Trainer-scheduled upcoming workout sessions for a client")
@RestController
@RequiredArgsConstructor
public class WorkoutScheduleController {

    private final WorkoutScheduleService workoutScheduleService;

    @Operation(summary = "Create a schedule (recurring or one-off) of upcoming sessions for a client",
            description = "Materializes every occurrence immediately as an upcoming workout_sessions row "
                    + "(scheduledFor set, startedAt null) — the client sees them via the normal delta sync.")
    @PostMapping("/api/v1/trainer/schedules")
    @ResponseStatus(HttpStatus.CREATED)
    public ScheduleResponse create(@Valid @RequestBody ScheduleRequest request) {
        return workoutScheduleService.create(request);
    }

    @Operation(summary = "List a client's active schedules, with done/missed/remaining occurrence counts")
    @GetMapping("/api/v1/trainer/clients/{clientId}/schedules")
    public List<ScheduleSummaryResponse> findForClient(@PathVariable Long clientId) {
        return workoutScheduleService.findForClient(clientId);
    }

    @Operation(summary = "List a client's scheduled occurrences in a date range",
            description = "Includes upcoming, missed, done and cancelled occurrences, for the calendar/timeline view.")
    @GetMapping("/api/v1/trainer/clients/{clientId}/scheduled-sessions")
    public List<ScheduledSessionResponse> findScheduledSessions(
            @PathVariable Long clientId,
            @Parameter(description = "Inclusive lower bound (yyyy-MM-dd)")
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @Parameter(description = "Inclusive upper bound (yyyy-MM-dd)")
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return workoutScheduleService.findScheduledSessions(clientId, from, to);
    }

    @Operation(summary = "List every active client's scheduled occurrences in a date range",
            description = "Aggregated across the trainer's whole client roster, for the trainer calendar "
                    + "(docs/personal_trainer/12-edzo-naptar-terv.md). The range cannot span more than 62 days.")
    @GetMapping("/api/v1/trainer/scheduled-sessions")
    public List<TrainerCalendarSessionResponse> findScheduledSessionsForTrainer(
            @Parameter(description = "Inclusive lower bound (yyyy-MM-dd)")
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @Parameter(description = "Inclusive upper bound (yyyy-MM-dd)")
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return workoutScheduleService.findScheduledSessionsForTrainer(from, to);
    }

    @Operation(summary = "Cancel a schedule",
            description = "Soft-deletes its future, not-yet-started occurrences; past (done/missed) occurrences are untouched.")
    @DeleteMapping("/api/v1/trainer/schedules/{scheduleId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancelSchedule(@PathVariable Long scheduleId) {
        workoutScheduleService.cancelSchedule(scheduleId);
    }

    @Operation(summary = "Cancel a single scheduled occurrence",
            description = "409 if it has already started, is in the past, or is already cancelled.")
    @DeleteMapping("/api/v1/trainer/scheduled-sessions/{sessionId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancelOccurrence(@PathVariable Long sessionId) {
        workoutScheduleService.cancelOccurrence(sessionId);
    }
}
