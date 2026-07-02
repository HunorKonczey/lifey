package com.lifey.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record ChangePasswordRequest(

        @NotBlank
        String currentPassword,

        @ValidPassword
        String newPassword
) {
}
