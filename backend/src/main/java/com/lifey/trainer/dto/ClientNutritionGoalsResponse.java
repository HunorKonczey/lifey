package com.lifey.trainer.dto;

public record ClientNutritionGoalsResponse(
        Integer dailyCalorieGoal,
        Integer dailyProteinGoal,
        Integer dailyCarbsGoal,
        Integer dailyFatGoal
) {
}
