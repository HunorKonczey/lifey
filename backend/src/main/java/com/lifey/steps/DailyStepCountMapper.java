package com.lifey.steps;

import com.lifey.steps.dto.DailyStepCountRequest;
import com.lifey.steps.dto.DailyStepCountResponse;

/**
 * Maps between {@link DailyStepCount} entities and daily-step-count DTOs.
 */
public final class DailyStepCountMapper {

    private DailyStepCountMapper() {
    }

    public static DailyStepCount toEntity(DailyStepCountRequest request) {
        DailyStepCount entry = new DailyStepCount();
        entry.setDate(request.date());
        entry.setSteps(request.steps());
        return entry;
    }

    public static DailyStepCountResponse toResponse(DailyStepCount entry) {
        return new DailyStepCountResponse(
                entry.getId(),
                entry.getDate(),
                entry.getSteps(),
                entry.getUpdatedAt(),
                entry.getDeletedAt()
        );
    }
}
