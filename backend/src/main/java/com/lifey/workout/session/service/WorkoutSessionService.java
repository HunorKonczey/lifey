package com.lifey.workout.session.service;

import com.lifey.workout.session.dto.WorkoutSessionRequest;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

public interface WorkoutSessionService {

    List<WorkoutSessionResponse> findAll();

    /**
     * Paged history view — backs `GET /workout-sessions?page=`, an additive
     * alternative to {@link #findAll()} for callers that want to page through
     * a long history instead of pulling everything at once.
     */
    Page<WorkoutSessionResponse> findPage(Pageable pageable);

    /**
     * Same as {@link #findPage(Pageable)}, scoped to an explicit user rather
     * than the current one — used by the trainer client-workout-sessions
     * endpoint (see docs/personal_trainer/03-backend-terv.md). Callers are
     * responsible for authorizing {@code userId} first (e.g. via
     * {@code TrainerAccessService.requireActiveClient}).
     */
    Page<WorkoutSessionResponse> findPageForUser(Long userId, Pageable pageable);

    Page<WorkoutSessionResponse> findDelta(Instant updatedSince, Pageable pageable);

    WorkoutSessionResponse create(WorkoutSessionRequest request);

    WorkoutSessionResponse update(Long id, WorkoutSessionRequest request);

    void delete(Long id);
}
