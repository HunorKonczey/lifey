package com.lifey.workout.session.service;

import com.lifey.workout.session.dto.WorkoutSessionRequest;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

public interface WorkoutSessionService {

    List<WorkoutSessionResponse> findAll();

    Page<WorkoutSessionResponse> findDelta(Instant updatedSince, Pageable pageable);

    WorkoutSessionResponse create(WorkoutSessionRequest request);

    WorkoutSessionResponse update(Long id, WorkoutSessionRequest request);

    void delete(Long id);
}
