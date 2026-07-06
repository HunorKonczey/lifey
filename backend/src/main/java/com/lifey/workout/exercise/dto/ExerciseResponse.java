package com.lifey.workout.exercise.dto;

import java.time.Instant;

public record ExerciseResponse(
        Long id,
        String name,
        String category,
        String equipment,
        Instant updatedAt,
        Instant deletedAt,
        // Non-null only for a trainer-assigned copy (docs/personal_trainer/05-mobil-terv.md
        // §2) — drives the mobile "Edzőtől" badge.
        Long originTrainerId
) {
}
