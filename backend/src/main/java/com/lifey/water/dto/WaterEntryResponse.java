package com.lifey.water.dto;

import java.time.Instant;

public record WaterEntryResponse(
        Long id,
        Instant consumedAt,
        Double volumeLiters,
        Long sourceId,
        String sourceName,
        Instant updatedAt,
        Instant deletedAt
) {
}
