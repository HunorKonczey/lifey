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
        double totalElevationGainMeters,
        // Dietary fibre and sugars (LIF-148): the sum of the foods that have a figure - null when none has, which is not 0.
        Double totalFiber,
        Double totalSugar,
        // True when some entry's food has no fibre/sugar figure, so the totals above are a lower bound.
        boolean fiberSugarPartial
) {
    public StatisticsResponse(Double totalCalories, Double totalProtein, Double totalCarbs, Double totalFat,
                              Integer workoutCount, Double latestWeight, Double totalWater, int strengthWorkoutCount,
                              int cardioWorkoutCount, int movingMinutes, double totalDistanceMeters,
                              double totalElevationGainMeters) {
        this(totalCalories, totalProtein, totalCarbs, totalFat, workoutCount, latestWeight, totalWater,
                strengthWorkoutCount, cardioWorkoutCount, movingMinutes, totalDistanceMeters, totalElevationGainMeters,
                null, null, false);
    }
}
