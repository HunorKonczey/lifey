package com.lifey.weight;

import com.lifey.weight.dto.WeightRequest;
import com.lifey.weight.dto.WeightResponse;

/**
 * Maps between {@link WeightEntry} entities and weight DTOs.
 */
public final class WeightMapper {

    private WeightMapper() {
    }

    public static WeightEntry toEntity(WeightRequest request) {
        WeightEntry entry = new WeightEntry();
        entry.setDate(request.date());
        entry.setWeight(request.weight());
        return entry;
    }

    public static WeightResponse toResponse(WeightEntry entry) {
        return new WeightResponse(
                entry.getId(),
                entry.getDate(),
                entry.getWeight(),
                entry.getUpdatedAt(),
                entry.getDeletedAt()
        );
    }
}
