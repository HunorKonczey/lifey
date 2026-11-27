package com.lifey.vitals.dto;

import com.lifey.vitals.HrvMethod;

import java.time.Instant;
import java.time.LocalDate;

public record DailyVitalsResponse(
        Long id,
        LocalDate date,
        Integer restingHr,
        Double hrvMs,
        HrvMethod hrvMethod,
        Instant updatedAt,
        Instant deletedAt
) {
}
