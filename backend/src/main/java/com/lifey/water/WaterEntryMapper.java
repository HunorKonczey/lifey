package com.lifey.water;

import com.lifey.water.dto.WaterEntryResponse;

/**
 * Maps {@link WaterEntry} entities to water-entry DTOs. Request-side mapping
 * lives in the service because it needs to resolve {@code sourceId}.
 */
final class WaterEntryMapper {

    private WaterEntryMapper() {
    }

    static WaterEntryResponse toResponse(WaterEntry entry) {
        WaterSource source = entry.getWaterSource();
        return new WaterEntryResponse(
                entry.getId(),
                entry.getConsumedAt(),
                entry.getVolumeLiters(),
                source != null ? source.getId() : null,
                source != null ? source.getName() : null
        );
    }
}
