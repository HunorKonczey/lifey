package com.lifey.workout.session.dto;

/**
 * Response side of {@link CardioDetailsRequest} — see its doc for field
 * meanings. Null on a STRENGTH-kind {@code WorkoutSessionResponse}.
 */
public record CardioDetailsResponse(
        Double distanceMeters,
        Double elevationGainMeters,
        Double elevationLossMeters,
        Double maxAltitudeMeters,
        Integer steps,
        Double avgCadence,
        Double maxCadence,
        Integer best1kSeconds,
        Integer best5kSeconds,
        Integer best10kSeconds,
        Double avgWatts,
        Double maxWatts,
        Integer resistanceLevel,
        Double deviceCalories,
        Double maxHeartRate,
        Integer hrZone1Seconds,
        Integer hrZone2Seconds,
        Integer hrZone3Seconds,
        Integer hrZone4Seconds,
        Integer hrZone5Seconds,
        Integer intensity,
        String venue,
        String gameFormat,
        Integer scorePoints,
        Integer scoreAssists,
        Integer scoreRebounds,
        String distanceSource,
        String caloriesSource,
        String routePolyline,
        Integer routePointCount
) {
}
