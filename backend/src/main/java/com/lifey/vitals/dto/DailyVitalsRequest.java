package com.lifey.vitals.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.lifey.vitals.HrvMethod;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.time.LocalDate;

/**
 * One day of vitals (docs/integrations/89 D-G8). The bounds match the {@code V100} check constraints, so a bad value
 * is a 400 here instead of a database error.
 */
public record DailyVitalsRequest(
        @NotNull
        LocalDate date,

        @Min(20)
        @Max(250)
        Integer restingHr,

        @Positive
        @DecimalMax("1000")
        Double hrvMs,

        HrvMethod hrvMethod
) {

    /** An HRV value needs its method, and a method needs a value. */
    @JsonIgnore
    @AssertTrue(message = "hrvMs and hrvMethod must be given together")
    public boolean isHrvMethodWithValue() {
        return (hrvMs == null) == (hrvMethod == null);
    }

    /** A day with neither value means nothing. */
    @JsonIgnore
    @AssertTrue(message = "restingHr or hrvMs is required")
    public boolean isSomeValue() {
        return restingHr != null || hrvMs != null;
    }
}
