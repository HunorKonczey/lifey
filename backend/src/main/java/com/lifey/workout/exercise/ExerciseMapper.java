package com.lifey.workout.exercise;

import com.lifey.workout.exercise.dto.ExerciseRequest;
import com.lifey.workout.exercise.dto.ExerciseResponse;

/**
 * Maps between {@link Exercise} entities and exercise DTOs.
 */
final class ExerciseMapper {

    private ExerciseMapper() {
    }

    static Exercise toEntity(ExerciseRequest request) {
        Exercise exercise = new Exercise();
        apply(exercise, request);
        return exercise;
    }

    static void apply(Exercise exercise, ExerciseRequest request) {
        exercise.setName(request.name());
    }

    static ExerciseResponse toResponse(Exercise exercise) {
        return new ExerciseResponse(exercise.getId(), exercise.getName());
    }
}
