package com.lifey.workout.session.dto;

import java.time.Instant;
import java.util.List;

public record WorkoutSessionRequest(
        Instant startedAt,
        Instant finishedAt,
        List<ExerciseSetRequest> sets
) {
}
