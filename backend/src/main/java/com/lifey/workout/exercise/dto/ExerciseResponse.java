package com.lifey.workout.exercise.dto;

import java.time.Instant;

public record ExerciseResponse(
        Long id,
        String name,
        String category,
        String equipment,
        String description,
        Instant updatedAt,
        Instant deletedAt,
        // Non-null only for a trainer-assigned copy (docs/personal_trainer/05-mobil-terv.md
        // §2) — drives the mobile "Edzőtől" badge.
        Long originTrainerId,
        // Null means "use the user's default rest duration" (docs/39-rest-timer-plan.md §2.2).
        Integer defaultRestSeconds
) {
}
