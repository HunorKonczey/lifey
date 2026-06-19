package com.lifey.settings.dto;

import com.lifey.settings.ThemePreference;
import com.lifey.settings.UnitSystem;
import jakarta.validation.constraints.NotNull;
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

        @NotNull
        ThemePreference theme
) {
}
