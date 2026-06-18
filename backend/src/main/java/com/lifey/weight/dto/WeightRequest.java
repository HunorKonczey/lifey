package com.lifey.weight.dto;

import java.time.LocalDate;

public record WeightRequest(
        LocalDate date,
        Double weight
) {
}
