package com.lifey.statistics.dto;

public record StatisticsResponse(
        Double totalCalories,
        Double totalProtein,
        Integer workoutCount,
        Double latestWeight
) {
}
