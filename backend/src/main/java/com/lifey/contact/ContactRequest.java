package com.lifey.contact;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record ContactRequest(

        @NotBlank
        @Size(max = 100)
        String name,

        @NotBlank
        @Email
        @Size(max = 254)
        String email,

        @NotBlank
        @Size(max = 2000)
        String message,

        /** Which marketing locale the visitor was on — "hu" or "en" (web/src/i18n/routing.ts). */
        @Pattern(regexp = "hu|en")
        String locale
) {
}
