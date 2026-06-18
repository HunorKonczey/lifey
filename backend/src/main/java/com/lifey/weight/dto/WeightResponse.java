package com.lifey.weight.dto;

import java.time.LocalDate;

public record WeightResponse(
        Long id,
        LocalDate date,
        Double weight
) {
}
