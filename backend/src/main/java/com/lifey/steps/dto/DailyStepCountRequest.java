package com.lifey.steps.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.time.LocalDate;

public record DailyStepCountRequest(

        @NotNull
        LocalDate date,

        @NotNull
        @PositiveOrZero
        Integer steps
) {
}
