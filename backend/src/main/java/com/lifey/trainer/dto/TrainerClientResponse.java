package com.lifey.trainer.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/**
 * An active client as seen by the trainer — includes the dashboard-card
 * metrics from docs/personal_trainer/06-design.md §3.2 (weight sparkline,
 * assigned plan count, weekly workout frequency) plus the raw compliance
 * facts from docs/29-compliance-overview-plan.md (thresholds/flags are a
 * web-side concern; the backend only reports what happened and when).
 */
public record TrainerClientResponse(
        Long clientId,
        String clientEmail,
        Instant activeSince,
        List<WeightTrendPoint> weightTrend,
        int assignedPlanCount,
        int workoutsPerWeek,
        Instant lastActivityAt,
        LocalDate lastWeightAt,
        int missedWorkoutCount
) {
}
