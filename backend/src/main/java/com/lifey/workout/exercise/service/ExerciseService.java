package com.lifey.workout.exercise.service;

import com.lifey.workout.exercise.dto.ExerciseRequest;
import com.lifey.workout.exercise.dto.ExerciseResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

/**
 * Application service for managing exercises.
 */
public interface ExerciseService {

    List<ExerciseResponse> findAll();

    Page<ExerciseResponse> findDelta(Instant updatedSince, Pageable pageable);

    ExerciseResponse findById(Long id);

    ExerciseResponse create(ExerciseRequest request);

    ExerciseResponse update(Long id, ExerciseRequest request);

    void delete(Long id);
}
