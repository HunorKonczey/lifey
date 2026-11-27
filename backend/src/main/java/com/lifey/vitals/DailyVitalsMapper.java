package com.lifey.vitals;

import com.lifey.vitals.dto.DailyVitalsRequest;
import com.lifey.vitals.dto.DailyVitalsResponse;

/** Maps between {@link DailyVitals} entities and their DTOs. */
public final class DailyVitalsMapper {

    private DailyVitalsMapper() {
    }

    /** Copies every value of the request onto the entity: a value the request leaves out is cleared. */
    public static void apply(DailyVitals vitals, DailyVitalsRequest request) {
        vitals.setDate(request.date());
        vitals.setRestingHr(request.restingHr());
        vitals.setHrvMs(request.hrvMs());
        vitals.setHrvMethod(request.hrvMethod());
    }

    public static DailyVitalsResponse toResponse(DailyVitals vitals) {
        return new DailyVitalsResponse(
                vitals.getId(),
                vitals.getDate(),
                vitals.getRestingHr(),
                vitals.getHrvMs(),
                vitals.getHrvMethod(),
                vitals.getUpdatedAt(),
                vitals.getDeletedAt()
        );
    }
}
