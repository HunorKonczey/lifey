package com.lifey.trainer.dto;

import jakarta.validation.constraints.PositiveOrZero;

public record ClientNutritionGoalsRequest(
        @PositiveOrZero
        Integer dailyCalorieGoal,

        @PositiveOrZero
        Integer dailyProteinGoal,

        @PositiveOrZero
        Integer dailyCarbsGoal,

        @PositiveOrZero
        Integer dailyFatGoal
) {
}
