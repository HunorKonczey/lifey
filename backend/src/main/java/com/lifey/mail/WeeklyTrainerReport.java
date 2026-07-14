package com.lifey.mail;

import java.time.LocalDate;
import java.util.List;

/**
 * One trainer's weekly digest (docs/33-weekly-trainer-report-plan.md) — a
 * section per active client, computed in the client's own local week
 * (see {@code WeeklyReportServiceImpl}). Nulls carry the "nothing to
 * report" cases: no calorie goal set, nothing logged, no weigh-in this
 * week.
 */
public record WeeklyTrainerReport(LocalDate weekStart, LocalDate weekEnd, List<ClientWeekSummary> clients) {

    public record ClientWeekSummary(
            String clientName,
            int completedWorkouts,
            int missedWorkouts,
            int daysLogged,
            Integer daysWithinGoal,
            Integer avgCalories,
            Double weightKg,
            Double weightChangeKg) {
    }
}
