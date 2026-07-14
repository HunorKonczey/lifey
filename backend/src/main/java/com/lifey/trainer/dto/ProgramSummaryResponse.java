package com.lifey.trainer.dto;

public record ProgramSummaryResponse(
        Long id,
        String name,
        int weeksCount,
        /* Distinct days of week used across the grid — "how many times a week" at a glance. */
        int slotsPerWeek,
        int activeAssignmentCount
) {
}
