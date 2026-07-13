package com.lifey.trainer.dto;

import java.time.LocalDate;

public record ProgramAssignmentResponse(
        Long assignmentId,
        String programName,
        LocalDate startDate,
        LocalDate endDate,
        int occurrenceCount
) {
}
