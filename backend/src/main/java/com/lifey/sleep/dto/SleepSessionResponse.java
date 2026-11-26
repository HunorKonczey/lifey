package com.lifey.sleep.dto;

import java.time.Instant;

public record SleepSessionResponse(
        Long id,
        Instant startedAt,
        Instant endedAt,
        Integer asleepMinutes,
        Integer deepMinutes,
        Integer lightMinutes,
        Integer remMinutes,
        Integer awakeMinutes,
        String sourceAppName,
        String healthRecordId,
        Instant updatedAt,
        Instant deletedAt
) {
}
