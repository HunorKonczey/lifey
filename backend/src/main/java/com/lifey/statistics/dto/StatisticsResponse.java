package com.lifey.statistics.dto;

/**
 * {@code workoutCount}'s meaning stays unchanged — "all sessions", strength
 * and cardio alike (docs/cardio/56-cardio-statistics-plan.md D-C3.1). The
 * fields below it are the additive fajta-bontás (D-C3.2): a pre-C3 client
 * ignores them; {@code workoutCount} remains the headline number either way.
 */
public record StatisticsResponse(
        Double totalCalories,
        Double totalProtein,
        Double totalCarbs,
        Double totalFat,
        Integer workoutCount,
        Double latestWeight,
        Double totalWater,
        int strengthWorkoutCount,
        int cardioWorkoutCount,
        int movingMinutes,
        double totalDistanceMeters,
        double totalElevationGainMeters
) {
}
