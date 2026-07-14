package com.lifey.trainer.dto;

import java.time.Instant;
import java.time.LocalDate;

public record ProgramAssignmentSummaryResponse(
        Long id,
        Long clientId,
        Long programId,
        /* Snapshot at assignment time — survives the program being renamed or deleted since. */
        String programName,
        LocalDate startDate,
        LocalDate endDate,
        int doneCount,
        int missedCount,
        int remainingCount,
        Instant cancelledAt
) {
}
