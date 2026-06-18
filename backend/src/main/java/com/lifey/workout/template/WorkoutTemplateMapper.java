package com.lifey.workout.template;

import com.lifey.workout.template.dto.WorkoutTemplateResponse;

import java.util.List;

/**
 * Maps {@link WorkoutTemplate} entities to template DTOs. Request-side mapping lives
 * in the service because it needs to resolve {@code exerciseId}s.
 */
final class WorkoutTemplateMapper {

    private WorkoutTemplateMapper() {
    }

    static WorkoutTemplateResponse toResponse(WorkoutTemplate template) {
        List<Long> exerciseIds = template.getExercises().stream()
                .map(link -> link.getExercise().getId())
                .toList();

        return new WorkoutTemplateResponse(
                template.getId(),
                template.getName(),
                exerciseIds
        );
    }
}
