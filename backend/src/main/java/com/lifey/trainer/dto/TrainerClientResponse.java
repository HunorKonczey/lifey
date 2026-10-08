package com.lifey.trainer.dto;

import com.lifey.userdetails.PrimaryGoal;

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
        int missedWorkoutCount,
        /**
         * Mean daily calories over the days with meals logged in the last 7
         * days (the client's own local days), or null when nothing was logged —
         * the "Avg kcal" KPI of the mobile client card (docs/redesign/
         * 77-mobile-redesign-plan.md R6.2). Read-only, derived on request.
         */
        Integer avgCalories7d,
        /**
         * Strength personal records the client set in the last 7 days — the
         * "🏆 2 PRs this week" chip. Derived from the set history the same way
         * the phone derives them ({@link com.lifey.trainer.PersonalRecordCounter}).
         * Null only if it could not be computed; 0 is a real answer.
         */
        Integer prCount7d,
        /**
         * The client's own daily calorie goal from their settings, or null when they never set one (or have no
         * settings row yet) — what lets the trainer's client card show "96 % of the goal" instead of a bare average
         * (docs/redesign-web/78-web-redesign-plan.md W7.b1). Read-only, the same value the trainer's nutrition-goals
         * endpoint returns.
         */
        Integer dailyCalorieGoal,
        /**
         * The client's own daily step goal from their settings, or null when they never set one — what lets the
         * trainer's steps tile say "84 % of goal" (docs/redesign/77-mobile-redesign-plan.md R6.5, LIF-101). Read-only,
         * like {@link #dailyCalorieGoal}; no default is applied here, the apps decide what a missing goal means.
         */
        Integer dailyStepGoal,
        /**
         * Occurrences the trainer scheduled for the client on the last 7 days' dates (today included, cancelled ones
         * left out), and how many of them the client started — "3 of 4 planned" on the trainer's workouts tile
         * (LIF-101). Zero planned means nothing was asked of the client that week, not a missing figure.
         */
        int plannedSessions7d,
        int completedSessions7d,
        /**
         * What the client said they are training for in onboarding, or null when they have not been through it —
         * the "Goal: build muscle" line of the trainer's client header (LIF-102). Read-only; the client changes it
         * in their own profile.
         */
        PrimaryGoal primaryGoal
) {
}
