package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.trainer.ContentType;
import com.lifey.trainer.Recurrence;
import com.lifey.trainer.WorkoutScheduleRepository;
import com.lifey.trainer.dto.AssignmentRequest;
import com.lifey.trainer.dto.OccurrenceStatus;
import com.lifey.trainer.dto.ScheduleRequest;
import com.lifey.trainer.dto.ScheduleResponse;
import com.lifey.trainer.dto.ScheduleSummaryResponse;
import com.lifey.trainer.dto.ScheduledSessionResponse;
import com.lifey.trainer.entity.WorkoutSchedule;
import com.lifey.trainer.exception.EmptyRecurrenceException;
import com.lifey.trainer.exception.OccurrenceNotCancellableException;
import com.lifey.trainer.exception.ScheduleHorizonExceededException;
import com.lifey.trainer.exception.ScheduleInPastException;
import com.lifey.trainer.exception.ScheduleNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.session.WorkoutSession;
import com.lifey.workout.session.WorkoutSessionRepository;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/**
 * Schedule creation/materialization/cancellation (docs/personal_trainer/
 * 09-utemezett-edzesek-domain-backend.md). Occurrences are plain
 * {@code workout_sessions} rows — see {@link WorkoutSession#getScheduledFor()}.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class WorkoutScheduleServiceImpl implements WorkoutScheduleService {

    private final WorkoutScheduleRepository workoutScheduleRepository;
    private final WorkoutSessionRepository workoutSessionRepository;
    private final WorkoutTemplateRepository workoutTemplateRepository;
    private final ContentAssignmentService contentAssignmentService;
    private final TrainerAccessService trainerAccessService;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    public ScheduleResponse create(ScheduleRequest request) {
        Long trainerId = currentUserProvider.getUserId();
        trainerAccessService.requireActiveClient(trainerId, request.clientId());

        WorkoutTemplate sourceTemplate = workoutTemplateRepository.findByIdAndUserId(request.templateId(), trainerId)
                .orElseThrow(() -> new ResourceNotFoundException("Workout template not found: " + request.templateId()));

        if (request.startDate().isBefore(LocalDate.now())) {
            throw new ScheduleInPastException("Schedule start date cannot be in the past");
        }
        if (request.recurrence() == Recurrence.WEEKLY && request.daysOfWeek().isEmpty()) {
            throw new EmptyRecurrenceException("WEEKLY recurrence requires at least one day of week");
        }

        LocalDate endDate = request.recurrence() == Recurrence.ONCE ? request.startDate() : request.endDate();
        if (endDate.isAfter(request.startDate().plusMonths(3))) {
            throw new ScheduleHorizonExceededException("Schedule cannot span more than 3 months");
        }

        List<LocalDate> occurrenceDates = OccurrenceGenerator.generate(
                request.recurrence(), request.daysOfWeek(), request.startDate(), endDate);

        WorkoutTemplate clientTemplate = resolveClientTemplate(trainerId, request.clientId(), sourceTemplate);

        WorkoutSchedule schedule = new WorkoutSchedule();
        schedule.setTrainer(userRepository.getReferenceById(trainerId));
        schedule.setClient(userRepository.getReferenceById(request.clientId()));
        schedule.setSourceTemplateId(sourceTemplate.getId());
        schedule.setClientTemplate(clientTemplate);
        schedule.setRecurrence(request.recurrence());
        schedule.setDaysOfWeek(request.recurrence() == Recurrence.WEEKLY
                ? OccurrenceGenerator.formatDaysOfWeek(request.daysOfWeek()) : null);
        schedule.setTimeOfDay(request.timeOfDay());
        schedule.setStartDate(request.startDate());
        schedule.setEndDate(endDate);
        schedule.setCreatedAt(Instant.now());
        WorkoutSchedule saved = workoutScheduleRepository.save(schedule);

        User client = userRepository.getReferenceById(request.clientId());
        for (LocalDate date : occurrenceDates) {
            WorkoutSession occurrence = new WorkoutSession();
            occurrence.setUser(client);
            occurrence.setScheduledFor(date);
            occurrence.setScheduledTime(request.timeOfDay());
            occurrence.setScheduleId(saved.getId());
            occurrence.setTemplate(clientTemplate);
            occurrence.setTemplateName(clientTemplate.getName());
            workoutSessionRepository.save(occurrence);
        }

        return new ScheduleResponse(
                saved.getId(), request.clientId(), sourceTemplate.getId(), clientTemplate.getName(),
                request.recurrence(), request.daysOfWeek(), request.timeOfDay(),
                request.startDate(), endDate, occurrenceDates.size());
    }

    /**
     * Reuses the client's existing live copy of this exact trainer template if one
     * already exists (from an earlier assignment or schedule); otherwise deep-copies
     * it via {@link ContentAssignmentService} — scheduling is thus an implicit assignment.
     */
    private WorkoutTemplate resolveClientTemplate(Long trainerId, Long clientId, WorkoutTemplate sourceTemplate) {
        return workoutTemplateRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(
                        clientId, trainerId, sourceTemplate.getId())
                .orElseGet(() -> {
                    Long copiedId = contentAssignmentService.assign(
                            new AssignmentRequest(clientId, ContentType.TEMPLATE, sourceTemplate.getId())).copiedId();
                    return workoutTemplateRepository.getReferenceById(copiedId);
                });
    }

    @Override
    @Transactional(readOnly = true)
    public List<ScheduleSummaryResponse> findForClient(Long clientId) {
        Long trainerId = currentUserProvider.getUserId();
        trainerAccessService.requireActiveClient(trainerId, clientId);

        LocalDate today = LocalDate.now();
        return workoutScheduleRepository.findByTrainerIdAndClientIdAndCancelledAtIsNullOrderByStartDateDesc(trainerId, clientId)
                .stream()
                .map(schedule -> toSummary(schedule, today))
                .toList();
    }

    private ScheduleSummaryResponse toSummary(WorkoutSchedule schedule, LocalDate today) {
        long done = workoutSessionRepository.countByScheduleIdAndStartedAtIsNotNull(schedule.getId());
        long missed = workoutSessionRepository.countByScheduleIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForBefore(
                schedule.getId(), today);
        long remaining = workoutSessionRepository.countByScheduleIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForGreaterThanEqual(
                schedule.getId(), today);

        return new ScheduleSummaryResponse(
                schedule.getId(), schedule.getClient().getId(), schedule.getSourceTemplateId(),
                schedule.getClientTemplate().getName(), schedule.getRecurrence(),
                OccurrenceGenerator.parseDaysOfWeek(schedule.getDaysOfWeek()), schedule.getTimeOfDay(),
                schedule.getStartDate(), schedule.getEndDate(),
                (int) done, (int) missed, (int) remaining, schedule.getCancelledAt());
    }

    @Override
    @Transactional(readOnly = true)
    public List<ScheduledSessionResponse> findScheduledSessions(Long clientId, LocalDate from, LocalDate to) {
        Long trainerId = currentUserProvider.getUserId();
        trainerAccessService.requireActiveClient(trainerId, clientId);

        return workoutSessionRepository
                .findByUserIdAndScheduledForIsNotNullAndScheduledForBetweenOrderByScheduledForAscScheduledTimeAsc(
                        clientId, from, to)
                .stream()
                .map(this::toOccurrenceResponse)
                .toList();
    }

    private ScheduledSessionResponse toOccurrenceResponse(WorkoutSession session) {
        OccurrenceStatus status;
        if (session.getDeletedAt() != null) {
            status = OccurrenceStatus.CANCELLED;
        } else if (session.getStartedAt() != null) {
            status = OccurrenceStatus.DONE;
        } else if (session.getScheduledFor().isBefore(LocalDate.now())) {
            status = OccurrenceStatus.MISSED;
        } else {
            status = OccurrenceStatus.UPCOMING;
        }
        return new ScheduledSessionResponse(
                session.getId(), session.getScheduledFor(), session.getScheduledTime(),
                session.getTemplateName(), status, session.getScheduleId());
    }

    @Override
    public void cancelSchedule(Long scheduleId) {
        Long trainerId = currentUserProvider.getUserId();
        WorkoutSchedule schedule = workoutScheduleRepository.findByIdAndTrainerId(scheduleId, trainerId)
                .orElseThrow(() -> new ScheduleNotFoundException("Schedule not found: " + scheduleId));
        cancel(schedule);
    }

    private void cancel(WorkoutSchedule schedule) {
        schedule.setCancelledAt(Instant.now());
        Instant now = Instant.now();
        for (WorkoutSession occurrence : workoutSessionRepository
                .findByScheduleIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForGreaterThanEqual(
                        schedule.getId(), LocalDate.now())) {
            occurrence.setDeletedAt(now);
        }
    }

    @Override
    public void cancelOccurrence(Long sessionId) {
        Long trainerId = currentUserProvider.getUserId();
        WorkoutSession occurrence = workoutSessionRepository.findById(sessionId)
                .filter(session -> session.getScheduleId() != null)
                .orElseThrow(() -> new ScheduleNotFoundException("Scheduled session not found: " + sessionId));

        workoutScheduleRepository.findByIdAndTrainerId(occurrence.getScheduleId(), trainerId)
                .orElseThrow(() -> new ScheduleNotFoundException("Scheduled session not found: " + sessionId));

        if (occurrence.getStartedAt() != null || occurrence.getDeletedAt() != null
                || occurrence.getScheduledFor().isBefore(LocalDate.now())) {
            throw new OccurrenceNotCancellableException(
                    "Only a future, not-yet-started occurrence can be cancelled: " + sessionId);
        }
        occurrence.setDeletedAt(Instant.now());
    }

    @Override
    public void cancelActiveSchedulesForPair(Long trainerId, Long clientId) {
        for (WorkoutSchedule schedule : workoutScheduleRepository
                .findByTrainerIdAndClientIdAndCancelledAtIsNull(trainerId, clientId)) {
            cancel(schedule);
        }
    }
}
