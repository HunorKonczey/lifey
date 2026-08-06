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
        /**
         * Added for the mobile chat's "new conversation" picker
         * (docs/chat/40-trainer-chat-plan.md, I2), which shows name + email
         * like every other person row in the app. Nullable: a client who
         * never filled in their profile has neither.
         */
        String clientFirstName,
        String clientLastName,
        Instant activeSince,
        List<WeightTrendPoint> weightTrend,
        int assignedPlanCount,
        int workoutsPerWeek,
        Instant lastActivityAt,
        LocalDate lastWeightAt,
        int missedWorkoutCount
) {
}
