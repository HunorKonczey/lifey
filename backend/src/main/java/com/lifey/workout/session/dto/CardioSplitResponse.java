package com.lifey.workout.session.dto;

import com.lifey.workout.session.cardio.IntervalIntensity;
import com.lifey.workout.session.cardio.SplitType;

/** Response side of {@link CardioSplitRequest}. */
public record CardioSplitResponse(
        Integer splitIndex,
        SplitType splitType,
        Double distanceMeters,
        Integer durationSeconds,
        Double elevationDeltaM,
        Double avgHeartRate,
        Double avgWatts,
        IntervalIntensity intensity
) {
}
