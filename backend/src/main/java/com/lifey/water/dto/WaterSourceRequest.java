package com.lifey.water.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record WaterSourceRequest(

        @NotBlank
        String name,

        @NotNull
        @Positive
        Double volumeLiters
) {
}
