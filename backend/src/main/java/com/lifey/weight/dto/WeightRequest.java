package com.lifey.weight.dto;

import com.lifey.common.validation.NotFutureDate;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.time.LocalDate;

public record WeightRequest(

        @NotNull
        @NotFutureDate
        LocalDate date,

        @NotNull
        @Positive
        Double weight,

        /** When the weigh-in was taken; absent = now. A time later than the server's now is clamped to now. */
        Instant recordedAt,

        /** Optional free text, at most 280 characters; blank is stored as none. */
        @Size(max = 280)
        String note
) {
    public WeightRequest(LocalDate date, Double weight) {
        this(date, weight, null, null);
    }
}
