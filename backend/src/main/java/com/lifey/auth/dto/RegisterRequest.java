package com.lifey.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record RegisterRequest(

        @NotBlank
        @Email
        String email,

        @ValidPassword
        String password
) {
}
