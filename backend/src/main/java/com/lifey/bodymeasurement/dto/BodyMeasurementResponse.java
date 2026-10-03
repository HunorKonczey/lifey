package com.lifey.bodymeasurement.dto;

import com.lifey.bodymeasurement.MeasurementSite;

import java.time.Instant;
import java.time.LocalDate;

public record BodyMeasurementResponse(
        Long id,
        LocalDate date,
        MeasurementSite site,
        Double valueCm,
        Instant updatedAt,
        Instant deletedAt
) {
}
