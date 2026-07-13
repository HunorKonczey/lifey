package com.lifey.settings;

import com.lifey.common.domain.BaseEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

/**
 * One row per user, created lazily (with defaults) on first access rather than
 * at registration time, so the auth module stays unaware of this feature.
 */
@Getter
@Setter
@Entity
@Table(name = "user_settings")
public class UserSettings extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "unit_system", nullable = false, length = 20)
    private UnitSystem unitSystem = UnitSystem.METRIC;

    @Column(name = "daily_calorie_goal")
    private Integer dailyCalorieGoal;

    @Column(name = "daily_protein_goal")
    private Integer dailyProteinGoal;

    @Column(name = "daily_carbs_goal")
    private Integer dailyCarbsGoal;

    @Column(name = "daily_fat_goal")
    private Integer dailyFatGoal;

    @Column(name = "daily_water_goal_liters")
    private Double dailyWaterGoalLiters;

    @Column(name = "daily_step_goal")
    private Integer dailyStepGoal;

    @Enumerated(EnumType.STRING)
    @Column(name = "theme", nullable = false, length = 20)
    private ThemePreference theme = ThemePreference.SYSTEM;

    @Enumerated(EnumType.STRING)
    @Column(name = "language", nullable = false, length = 20)
    private LanguagePreference language = LanguagePreference.SYSTEM;

    /**
     * Opt-out for the trainer-scheduled-workout push reminder
     * (docs/30-push-notifications-plan.md). Default true — a trainer-scheduled
     * workout is something the client signed up for.
     */
    @Column(name = "workout_reminder_enabled", nullable = false)
    private boolean workoutReminderEnabled = true;

    /**
     * Opt-out for the trainer-comment push notification
     * (docs/31-session-feedback-loop-plan.md). Default true — the trainer
     * relationship is something the client already accepted.
     */
    @Column(name = "trainer_comment_push_enabled", nullable = false)
    private boolean trainerCommentPushEnabled = true;

    /**
     * Opt-out for the trainer-nutrition-goals-changed push notification
     * (docs/32-trainer-nutrition-goals-plan.md). Default true — the trainer
     * relationship is something the client already accepted.
     */
    @Column(name = "trainer_goals_push_enabled", nullable = false)
    private boolean trainerGoalsPushEnabled = true;

    /**
     * Opt-out for the weekly trainer report email
     * (docs/33-weekly-trainer-report-plan.md). Trainer-facing only —
     * deliberately excluded from {@code SettingsRequest}/{@code
     * SettingsResponse}/{@code SettingsMapper} (the mobile settings
     * round-trip is a client surface); read/written via a small
     * trainer-scoped preferences endpoint instead. Default true — the
     * trainer chose to have clients, a weekly summary of them is core
     * value.
     */
    @Column(name = "weekly_report_email_enabled", nullable = false)
    private boolean weeklyReportEmailEnabled = true;
}
