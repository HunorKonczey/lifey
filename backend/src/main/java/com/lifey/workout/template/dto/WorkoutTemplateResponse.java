package com.lifey.workout.template.dto;

import java.time.Instant;
import java.util.List;

public record WorkoutTemplateResponse(
        Long id,
        String name,
        List<TemplateExerciseEntry> exercises,
        Instant updatedAt,
        Instant deletedAt,
        // Non-null only for a trainer-assigned copy (docs/personal_trainer/05-mobil-terv.md
        // §2) — drives the mobile "Edzőtől" badge.
        Long originTrainerId
) {
}
