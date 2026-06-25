package com.lifey.workout.template;

import com.lifey.workout.template.dto.TemplateExerciseEntry;
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
        List<TemplateExerciseEntry> exercises = template.getExercises().stream()
                .map(link -> new TemplateExerciseEntry(link.getExercise().getId(), link.getTargetSets()))
                .toList();

        return new WorkoutTemplateResponse(
                template.getId(),
                template.getName(),
                exercises
        );
    }
}
