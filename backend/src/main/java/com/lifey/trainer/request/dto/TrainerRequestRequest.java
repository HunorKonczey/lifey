package com.lifey.trainer.request.dto;

import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record TrainerRequestRequest(
        String motivation,
        /** Optional: what the applicant trained for (LIF-107). Blank is stored as none. */
        @Size(max = 500) String qualifications,
        @Positive Integer clientCount,
        String signupSource
) {
}
