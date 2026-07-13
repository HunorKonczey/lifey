package com.lifey.trainer.dto;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record ProgramAssignmentRequest(

        @NotNull
        Long clientId,

        /* Must be a Monday, not in the past — weeks are anchored Mon-Sun. */
        @NotNull
        LocalDate startDate
) {
}
