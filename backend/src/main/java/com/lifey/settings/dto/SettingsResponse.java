package com.lifey.settings.dto;

import com.lifey.settings.LanguagePreference;
import com.lifey.settings.ThemePreference;
import com.lifey.settings.UnitSystem;

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
        Boolean workoutReminderEnabled
) {
}
