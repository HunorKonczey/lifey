package com.lifey.settings.dto;

import com.lifey.settings.LanguagePreference;
import com.lifey.settings.ThemePreference;
import com.lifey.settings.UnitSystem;

import java.time.LocalTime;

public record SettingsResponse(
        UnitSystem unitSystem,
        Integer dailyCalorieGoal,
        Integer dailyProteinGoal,
        Integer dailyCarbsGoal,
        Integer dailyFatGoal,
        Double dailyWaterGoalLiters,
        Integer dailyStepGoal,
        ThemePreference theme,
        LanguagePreference language,
        Boolean workoutReminderEnabled,
        Boolean trainerCommentPushEnabled,
        Boolean trainerGoalsPushEnabled,
        Boolean programAssignedPushEnabled,
        Boolean chatPushEnabled,
        /** Null when the user has no quiet-hours window set (§5.4). */
        LocalTime chatQuietHoursStart,
        LocalTime chatQuietHoursEnd,
        Boolean restTimerEnabled,
        Integer defaultRestSeconds,
        /** Whether the people in the user's threads see them online (LIF-153); true when the server predates the switch. */
        Boolean chatOnlineVisible
) {

    /** Without the online switch: the older tests, and anything that does not care. */
    public SettingsResponse(UnitSystem unitSystem, Integer dailyCalorieGoal, Integer dailyProteinGoal, Integer dailyCarbsGoal,
                            Integer dailyFatGoal, Double dailyWaterGoalLiters, Integer dailyStepGoal, ThemePreference theme,
                            LanguagePreference language, Boolean workoutReminderEnabled, Boolean trainerCommentPushEnabled,
                            Boolean trainerGoalsPushEnabled, Boolean programAssignedPushEnabled, Boolean chatPushEnabled,
                            LocalTime chatQuietHoursStart, LocalTime chatQuietHoursEnd, Boolean restTimerEnabled,
                            Integer defaultRestSeconds) {
        this(unitSystem, dailyCalorieGoal, dailyProteinGoal, dailyCarbsGoal, dailyFatGoal, dailyWaterGoalLiters, dailyStepGoal,
                theme, language, workoutReminderEnabled, trainerCommentPushEnabled, trainerGoalsPushEnabled,
                programAssignedPushEnabled, chatPushEnabled, chatQuietHoursStart, chatQuietHoursEnd, restTimerEnabled,
                defaultRestSeconds, true);
    }
}
