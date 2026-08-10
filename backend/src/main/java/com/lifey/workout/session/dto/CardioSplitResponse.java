package com.lifey.workout.session.dto;

/** Response side of {@link CardioSplitRequest}. */
public record CardioSplitResponse(
        Integer splitIndex,
        Double distanceMeters,
        Integer durationSeconds,
        Double elevationDeltaM,
        Double avgHeartRate
) {
}
