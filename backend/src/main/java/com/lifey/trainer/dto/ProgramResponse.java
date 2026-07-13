package com.lifey.trainer.dto;

import java.time.Instant;
import java.util.List;

public record ProgramResponse(
        Long id,
        String name,
        int weeksCount,
        List<ProgramWorkoutResponse> workouts,
        Instant createdAt,
        Instant updatedAt
) {
}
