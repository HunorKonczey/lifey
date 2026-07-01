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
        exercise.setCategory(request.category());
        exercise.setEquipment(request.equipment());
    }

    static ExerciseResponse toResponse(Exercise exercise) {
        return new ExerciseResponse(
                exercise.getId(),
                exercise.getName(),
                exercise.getCategory() != null ? exercise.getCategory().name() : null,
                exercise.getEquipment() != null ? exercise.getEquipment().name() : null,
                exercise.getUpdatedAt(),
                exercise.getDeletedAt()
        );
    }
}
