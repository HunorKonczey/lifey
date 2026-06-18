package com.lifey.statistics.dto;

public record StatisticsResponse(
        Double totalCalories,
        Double totalProtein,
        Double totalCarbs,
        Double totalFat,
        Integer workoutCount,
        Double latestWeight
) {
}
