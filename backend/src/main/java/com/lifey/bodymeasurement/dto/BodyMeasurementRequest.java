package com.lifey.bodymeasurement.dto;

import com.lifey.bodymeasurement.MeasurementSite;
import com.lifey.common.validation.NotFutureDate;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record BodyMeasurementRequest(

        @NotNull
        @NotFutureDate
        LocalDate date,

        @NotNull
        MeasurementSite site,

        @NotNull
        @DecimalMin(value = "0.0", inclusive = false)
        @DecimalMax("300.0")
        Double valueCm
) {
}
