package com.lifey.workout.template;

import com.lifey.workout.template.dto.WorkoutTemplateRequest;
import com.lifey.workout.template.dto.WorkoutTemplateResponse;

import java.util.List;

public interface WorkoutTemplateService {

    List<WorkoutTemplateResponse> findAll();

    WorkoutTemplateResponse findById(Long id);

    WorkoutTemplateResponse create(WorkoutTemplateRequest request);

    WorkoutTemplateResponse update(Long id, WorkoutTemplateRequest request);

    void delete(Long id);
}
