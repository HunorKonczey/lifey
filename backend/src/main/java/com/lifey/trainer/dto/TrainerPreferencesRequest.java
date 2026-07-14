package com.lifey.trainer.dto;

import jakarta.validation.constraints.NotNull;

public record TrainerPreferencesRequest(
        @NotNull
        Boolean weeklyReportEmailEnabled
) {
}
