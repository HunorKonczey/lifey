package com.lifey.weight.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Positive;

import java.time.LocalDate;

public record WeightRequest(

        @NotNull
        @PastOrPresent
        LocalDate date,

        @NotNull
        @Positive
        Double weight
) {
}
