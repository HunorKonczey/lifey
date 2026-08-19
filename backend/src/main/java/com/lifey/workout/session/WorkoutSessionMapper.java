package com.lifey.workout.session;

import com.lifey.workout.session.cardio.CardioDetails;
import com.lifey.workout.session.cardio.CardioSplit;
import com.lifey.workout.session.dto.CardioDetailsResponse;
import com.lifey.workout.session.dto.CardioSplitResponse;
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
                .map(link -> new ExerciseSummary(
                        link.getExercise().getId(),
                        link.getExercise().getName(),
                        link.getTargetSets()))
                .toList();

        List<ExerciseSetResponse> sets = session.getSets().stream()
                .map(set -> new ExerciseSetResponse(
                        set.getExercise().getId(),
                        set.getExercise().getName(),
                        set.getReps(),
                        set.getWeight(),
                        set.getPerformedAt()))
                .toList();

        List<CardioSplitResponse> splits = session.getSplits().stream()
                .map(WorkoutSessionMapper::toSplitResponse)
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
                session.getTrainerComment(),
                session.getTrainerCommentAt(),
                session.getUpdatedAt(),
                session.getDeletedAt(),
                session.getSessionKind(),
                session.getActivityType(),
                session.getMovingSeconds(),
                toCardioResponse(session.getCardioDetails()),
                splits
        );
    }

    private static CardioDetailsResponse toCardioResponse(CardioDetails details) {
        if (details == null) return null;
        return new CardioDetailsResponse(
                details.getDistanceMeters(),
                details.getElevationGainMeters(),
                details.getElevationLossMeters(),
                details.getMaxAltitudeMeters(),
                details.getSteps(),
                details.getAvgCadence(),
                details.getMaxCadence(),
                details.getBest1kSeconds(),
                details.getBest5kSeconds(),
                details.getBest10kSeconds(),
                details.getAvgWatts(),
                details.getMaxWatts(),
                details.getResistanceLevel(),
                details.getDeviceCalories(),
                details.getMaxHeartRate(),
                details.getHrZone1Seconds(),
                details.getHrZone2Seconds(),
                details.getHrZone3Seconds(),
                details.getHrZone4Seconds(),
                details.getHrZone5Seconds(),
                details.getIntensity(),
                details.getVenue(),
                details.getGameFormat(),
                details.getScorePoints(),
                details.getScoreAssists(),
                details.getScoreRebounds(),
                details.getDistanceSource(),
                details.getCaloriesSource(),
                details.getRoutePolyline(),
                details.getRoutePointCount()
        );
    }

    private static CardioSplitResponse toSplitResponse(CardioSplit split) {
        return new CardioSplitResponse(
                split.getSplitIndex(),
                split.getSplitType(),
                split.getDistanceMeters(),
                split.getDurationSeconds(),
                split.getElevationDeltaM(),
                split.getAvgHeartRate(),
                split.getAvgWatts(),
                split.getIntensity()
        );
    }
}
