package com.lifey.workout.session;

import com.lifey.workout.session.dto.ExerciseSetResponse;
import com.lifey.workout.session.dto.ExerciseSummary;
import com.lifey.workout.session.dto.WorkoutSessionResponse;

import java.util.List;

/**
 * Maps {@link WorkoutSession} entities to session DTOs. Request-side mapping lives
 * in the service because it needs to resolve {@code exerciseId}s.
 */
public final class WorkoutSessionMapper {

    private WorkoutSessionMapper() {
    }

    public static WorkoutSessionResponse toResponse(WorkoutSession session) {
        List<ExerciseSummary> exercises = session.getPlannedExercises().stream()
                .map(link -> new ExerciseSummary(link.getExercise().getId(), link.getExercise().getName()))
                .toList();

        List<ExerciseSetResponse> sets = session.getSets().stream()
                .map(set -> new ExerciseSetResponse(
                        set.getExercise().getId(),
                        set.getExercise().getName(),
                        set.getReps(),
                        set.getWeight(),
                        set.getPerformedAt()))
                .toList();

        return new WorkoutSessionResponse(
                session.getId(),
                session.getStartedAt(),
                session.getFinishedAt(),
                exercises,
                sets,
                session.getActiveCalories(),
                session.getAverageHeartRate(),
                session.getHealthWorkoutId(),
                session.getTemplate() != null ? session.getTemplate().getId() : null,
                session.getTemplateName(),
                session.getScheduledFor(),
                session.getScheduledTime(),
                session.getScheduleId(),
                session.getRpe(),
                session.getFeedbackNote(),
                session.getUpdatedAt(),
                session.getDeletedAt()
        );
    }
}
