package com.lifey.trainer.request.dto;

import jakarta.validation.constraints.Positive;

public record TrainerRequestRequest(
        String motivation,
        @Positive Integer clientCount,
        String signupSource
) {
}
