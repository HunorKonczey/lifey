package com.lifey.steps.dto;

import java.time.LocalDate;

public record DailyStepCountResponse(
        Long id,
        LocalDate date,
        Integer steps
) {
}
