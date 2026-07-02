package com.lifey.water;

import com.lifey.water.dto.WaterSourceRequest;
import com.lifey.water.dto.WaterSourceResponse;

/**
 * Maps between {@link WaterSource} entities and water-source DTOs.
 */
public final class WaterSourceMapper {

    private WaterSourceMapper() {
    }

    public static void applyRequest(WaterSource source, WaterSourceRequest request) {
        source.setName(request.name());
        source.setVolumeLiters(request.volumeLiters());
    }

    public static WaterSourceResponse toResponse(WaterSource source) {
        return new WaterSourceResponse(
                source.getId(),
                source.getName(),
                source.getVolumeLiters()
        );
    }
}
