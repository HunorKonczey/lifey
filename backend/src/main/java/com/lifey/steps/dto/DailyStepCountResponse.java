package com.lifey.steps.dto;

import java.time.Instant;
import java.time.LocalDate;

public record DailyStepCountResponse(
        Long id,
        LocalDate date,
        Integer steps,
        Instant updatedAt,
        Instant deletedAt
) {
}
