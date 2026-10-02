package com.lifey.bodymeasurement.dto;

import com.lifey.bodymeasurement.MeasurementSite;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;

import java.time.LocalDate;

public record BodyMeasurementRequest(

        @NotNull
        @PastOrPresent
        LocalDate date,

        @NotNull
        MeasurementSite site,

        @NotNull
        @DecimalMin(value = "0.0", inclusive = false)
        @DecimalMax("300.0")
        Double valueCm
) {
}
