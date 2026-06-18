package com.lifey.workout.template;

import com.lifey.workout.template.dto.WorkoutTemplateRequest;
import com.lifey.workout.template.dto.WorkoutTemplateResponse;

import java.util.List;

public interface WorkoutTemplateService {

    List<WorkoutTemplateResponse> findAll();

    WorkoutTemplateResponse create(WorkoutTemplateRequest request);
}
