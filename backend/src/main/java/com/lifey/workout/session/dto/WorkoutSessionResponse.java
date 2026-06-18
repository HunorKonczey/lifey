package com.lifey.workout.session.dto;

import java.time.Instant;
import java.util.List;

public record WorkoutSessionResponse(
        Long id,
        Instant startedAt,
        Instant finishedAt,
        List<ExerciseSetResponse> sets
) {
}
