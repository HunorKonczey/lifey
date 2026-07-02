package com.lifey.workout.template.service;

import com.lifey.workout.template.dto.WorkoutTemplateRequest;
import com.lifey.workout.template.dto.WorkoutTemplateResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

public interface WorkoutTemplateService {

    List<WorkoutTemplateResponse> findAll();

    Page<WorkoutTemplateResponse> findDelta(Instant updatedSince, Pageable pageable);

    WorkoutTemplateResponse findById(Long id);

    WorkoutTemplateResponse create(WorkoutTemplateRequest request);

    WorkoutTemplateResponse update(Long id, WorkoutTemplateRequest request);

    void delete(Long id);
}
