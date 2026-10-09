package com.lifey.weight.dto;

import java.time.Instant;
import java.time.LocalDate;

public record WeightResponse(
        Long id,
        LocalDate date,
        Double weight,
        Instant updatedAt,
        Instant deletedAt,
        /** When the weigh-in was taken (LIF-115): the day's {@code date} says which day, this says when. */
        Instant recordedAt,
        String note
) {
    public WeightResponse(Long id, LocalDate date, Double weight, Instant updatedAt, Instant deletedAt) {
        this(id, date, weight, updatedAt, deletedAt, null, null);
    }
}
