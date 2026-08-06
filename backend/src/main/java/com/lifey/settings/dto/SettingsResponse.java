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
        Integer defaultRestSeconds
) {
}
