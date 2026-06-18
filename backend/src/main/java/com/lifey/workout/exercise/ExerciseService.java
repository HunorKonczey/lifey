package com.lifey.workout.exercise;

import com.lifey.workout.exercise.dto.ExerciseRequest;
import com.lifey.workout.exercise.dto.ExerciseResponse;

import java.util.List;

/**
 * Application service for managing exercises.
 */
public interface ExerciseService {

    List<ExerciseResponse> findAll();

    ExerciseResponse findById(Long id);

    ExerciseResponse create(ExerciseRequest request);

    ExerciseResponse update(Long id, ExerciseRequest request);

    void delete(Long id);
}
