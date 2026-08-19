package com.lifey.workout.session.dto;

/** Response side of {@link CardioWaypointRequest}. */
public record CardioWaypointResponse(
        Integer waypointIndex,
        Double latitude,
        Double longitude,
        Double altitudeMeters,
        String label
) {
}
