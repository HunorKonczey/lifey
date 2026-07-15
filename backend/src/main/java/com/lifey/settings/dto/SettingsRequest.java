package com.lifey.settings.dto;

import com.lifey.settings.LanguagePreference;
import com.lifey.settings.ThemePreference;
import com.lifey.settings.UnitSystem;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

public record SettingsRequest(

        @NotNull
        UnitSystem unitSystem,

        @PositiveOrZero
        Integer dailyCalorieGoal,

        @PositiveOrZero
        Integer dailyProteinGoal,

        @PositiveOrZero
        Integer dailyCarbsGoal,

        @PositiveOrZero
        Integer dailyFatGoal,

        @PositiveOrZero
        Double dailyWaterGoalLiters,

        @Positive
        Integer dailyStepGoal,

        @NotNull
        ThemePreference theme,

        @NotNull
        LanguagePreference language,

        @NotNull
        Boolean workoutReminderEnabled,

        @NotNull
        Boolean trainerCommentPushEnabled,

        @NotNull
        Boolean trainerGoalsPushEnabled,

        @NotNull
        Boolean programAssignedPushEnabled,

        @NotNull
        Boolean restTimerEnabled,

        @NotNull
        @Min(15)
        @Max(600)
        Integer defaultRestSeconds
) {
}
