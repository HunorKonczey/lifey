package com.lifey.workout.session;

import com.lifey.workout.session.dto.WorkoutSessionRequest;
import com.lifey.workout.session.dto.WorkoutSessionResponse;

import java.util.List;

public interface WorkoutSessionService {

    List<WorkoutSessionResponse> findAll();

    WorkoutSessionResponse create(WorkoutSessionRequest request);

    WorkoutSessionResponse update(Long id, WorkoutSessionRequest request);

    void delete(Long id);
}
