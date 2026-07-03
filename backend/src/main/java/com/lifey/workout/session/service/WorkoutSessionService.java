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
     * Same as {@link #findAll()}, scoped to an explicit user rather than the
     * current one — used by the trainer client-workout-sessions endpoint (see
     * docs/personal_trainer/03-backend-terv.md). Callers are responsible for
     * authorizing {@code userId} first (e.g. via
     * {@code TrainerAccessService.requireActiveClient}).
     */
    List<WorkoutSessionResponse> findAllForUser(Long userId);

    Page<WorkoutSessionResponse> findDelta(Instant updatedSince, Pageable pageable);

    WorkoutSessionResponse create(WorkoutSessionRequest request);

    WorkoutSessionResponse update(Long id, WorkoutSessionRequest request);

    void delete(Long id);
}
