package com.lifey.bodymeasurement;

import com.lifey.bodymeasurement.dto.BodyMeasurementRequest;
import com.lifey.bodymeasurement.dto.BodyMeasurementResponse;

public final class BodyMeasurementMapper {

    private BodyMeasurementMapper() {
    }

    public static BodyMeasurement toEntity(BodyMeasurementRequest request) {
        BodyMeasurement entry = new BodyMeasurement();
        entry.setDate(request.date());
        entry.setSite(request.site());
        entry.setValueCm(request.valueCm());
        return entry;
    }

    public static BodyMeasurementResponse toResponse(BodyMeasurement entry) {
        return new BodyMeasurementResponse(
                entry.getId(),
                entry.getDate(),
                entry.getSite(),
                entry.getValueCm(),
                entry.getUpdatedAt(),
                entry.getDeletedAt()
        );
    }
}
