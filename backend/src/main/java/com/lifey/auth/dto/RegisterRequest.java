package com.lifey.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RegisterRequest(

        @NotBlank
        @Email
        String email,

        @ValidPassword
        String password,

        @NotBlank
        String firstName,

        @NotBlank
        String lastName,

        /**
         * First-touch marketing attribution (docs/landing_page/65 D-W8) — the
         * {@code lifey_attrib} cookie's value, forwarded as-is. Optional: a
         * direct signup with no marketing-page visit (or cookies blocked) has
         * none, and that's fine — this is analytics, not a requirement.
         */
        @Size(max = 255)
        String signupSource
) {
}
