package com.lifey.sleep;

import com.lifey.sleep.dto.SleepSessionRequest;
import com.lifey.sleep.dto.SleepSessionResponse;

/**
 * Maps between {@link SleepSession} entities and sleep DTOs.
 */
public final class SleepSessionMapper {

    private SleepSessionMapper() {
    }

    public static SleepSession toEntity(SleepSessionRequest request) {
        SleepSession session = new SleepSession();
        session.setStartedAt(request.startedAt());
        session.setEndedAt(request.endedAt());
        session.setAsleepMinutes(request.asleepMinutes());
        session.setDeepMinutes(request.deepMinutes());
        session.setLightMinutes(request.lightMinutes());
        session.setRemMinutes(request.remMinutes());
        session.setAwakeMinutes(request.awakeMinutes());
        session.setSourceAppName(blankToNull(request.sourceAppName()));
        session.setHealthRecordId(blankToNull(request.healthRecordId()));
        return session;
    }

    public static SleepSessionResponse toResponse(SleepSession session) {
        return new SleepSessionResponse(
                session.getId(),
                session.getStartedAt(),
                session.getEndedAt(),
                session.getAsleepMinutes(),
                session.getDeepMinutes(),
                session.getLightMinutes(),
                session.getRemMinutes(),
                session.getAwakeMinutes(),
                session.getSourceAppName(),
                session.getHealthRecordId(),
                session.getUpdatedAt(),
                session.getDeletedAt()
        );
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
