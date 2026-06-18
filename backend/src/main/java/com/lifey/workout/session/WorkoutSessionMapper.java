package com.lifey.workout.session;

import com.lifey.workout.session.dto.ExerciseSetResponse;
import com.lifey.workout.session.dto.WorkoutSessionResponse;

import java.util.List;

/**
 * Maps {@link WorkoutSession} entities to session DTOs. Request-side mapping lives
 * in the service because it needs to resolve {@code exerciseId}s.
 */
final class WorkoutSessionMapper {

    private WorkoutSessionMapper() {
    }

    static WorkoutSessionResponse toResponse(WorkoutSession session) {
        List<ExerciseSetResponse> sets = session.getSets().stream()
                .map(set -> new ExerciseSetResponse(
                        set.getExercise().getId(),
                        set.getExercise().getName(),
                        set.getReps(),
                        set.getWeight()))
                .toList();

        return new WorkoutSessionResponse(
                session.getId(),
                session.getStartedAt(),
                session.getFinishedAt(),
                sets
        );
    }
}
