package com.lifey.workout.exercise;

import com.lifey.workout.exercise.dto.ExerciseRequest;
import com.lifey.workout.exercise.dto.ExerciseResponse;

/**
 * Maps between {@link Exercise} entities and exercise DTOs.
 */
public final class ExerciseMapper {

    private ExerciseMapper() {
    }

    public static Exercise toEntity(ExerciseRequest request) {
        Exercise exercise = new Exercise();
        apply(exercise, request);
        return exercise;
    }

    public static void apply(Exercise exercise, ExerciseRequest request) {
        exercise.setName(request.name());
        exercise.setCategory(request.category());
        exercise.setEquipment(request.equipment());
        exercise.setDescription(request.description());
        exercise.setDefaultRestSeconds(request.defaultRestSeconds());
    }

    public static ExerciseResponse toResponse(Exercise exercise) {
        return new ExerciseResponse(
                exercise.getId(),
                exercise.getName(),
                exercise.getCategory() != null ? exercise.getCategory().name() : null,
                exercise.getEquipment() != null ? exercise.getEquipment().name() : null,
                exercise.getDescription(),
                exercise.getUpdatedAt(),
                exercise.getDeletedAt(),
                exercise.getOriginTrainerId(),
                exercise.getDefaultRestSeconds()
        );
    }
}
