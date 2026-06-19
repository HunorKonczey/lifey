package com.lifey.water;

import com.lifey.water.dto.WaterSourceRequest;
import com.lifey.water.dto.WaterSourceResponse;

/**
 * Maps between {@link WaterSource} entities and water-source DTOs.
 */
final class WaterSourceMapper {

    private WaterSourceMapper() {
    }

    static void applyRequest(WaterSource source, WaterSourceRequest request) {
        source.setName(request.name());
        source.setVolumeLiters(request.volumeLiters());
    }

    static WaterSourceResponse toResponse(WaterSource source) {
        return new WaterSourceResponse(
                source.getId(),
                source.getName(),
                source.getVolumeLiters()
        );
    }
}
