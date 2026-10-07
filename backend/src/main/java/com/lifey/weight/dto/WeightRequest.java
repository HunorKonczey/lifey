package com.lifey.weight.dto;

import com.lifey.common.validation.NotFutureDate;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.time.LocalDate;

public record WeightRequest(

        @NotNull
        @NotFutureDate
        LocalDate date,

        @NotNull
        @Positive
        Double weight
) {
}
