package com.lifey.trainer.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record TrainerInviteRequest(
        @NotBlank
        @Email
        String email
) {
}
