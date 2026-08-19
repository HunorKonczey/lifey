package com.lifey.workout.session.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.PositiveOrZero;

/**
 * Cardio metrics for a CARDIO-kind session (docs/cardio/52-cardio-domain-backend-plan.md
 * §2.2, §3.2). Every field is optional — a family fills in only the columns
 * that apply to it (docs/cardio/51-cardio-overview-plan.md §3) — and must be
 * null on a STRENGTH-kind {@code WorkoutSessionRequest}; the service rejects
 * that combination (see {@code InvalidCardioRequestException}), not Bean
 * Validation, since it's cross-field.
 */
public record CardioDetailsRequest(

        // DISTANCE + MACHINE
        @PositiveOrZero Double distanceMeters,
        @PositiveOrZero Double elevationGainMeters,
        @PositiveOrZero Double elevationLossMeters,
        Double maxAltitudeMeters,
        @PositiveOrZero Integer steps,
        /* Steps/min for running, rpm for the indoor bike. */
        @PositiveOrZero Double avgCadence,
        @PositiveOrZero Double maxCadence,

        // Best efforts (docs/cardio/60 C6.1)
        /*
         * The fastest continuous 1/5/10 km inside the session, in seconds —
         * not the average pace extrapolated (docs/cardio/56 D-C3.8). Their
         * ordering (1k <= 5k <= 10k) is cross-field, so the service checks it,
         * not these annotations — see InvalidCardioRequestException.
         */
        @PositiveOrZero Integer best1kSeconds,
        @PositiveOrZero Integer best5kSeconds,
        @PositiveOrZero Integer best10kSeconds,

        // MACHINE
        @PositiveOrZero Double avgWatts,
        @PositiveOrZero Double maxWatts,
        @PositiveOrZero Integer resistanceLevel,
        /* The machine's own displayed calories — never auto-summed into daily active calories (docs/cardio/51 Q4). */
        @PositiveOrZero Double deviceCalories,

        // Shared physiological
        @PositiveOrZero Double maxHeartRate,
        @PositiveOrZero Integer hrZone1Seconds,
        @PositiveOrZero Integer hrZone2Seconds,
        @PositiveOrZero Integer hrZone3Seconds,
        @PositiveOrZero Integer hrZone4Seconds,
        @PositiveOrZero Integer hrZone5Seconds,

        // GAME
        @Min(1) @Max(5) Integer intensity,
        /* INDOOR or OUTDOOR; enforced at the DB layer (workout_sessions_kind_activity_ck's sibling, cardio_details_venue_ck). */
        String venue,
        /* Free-text format code, e.g. 5V5, SMALL_SIDED, PRACTICE. */
        String gameFormat,
        @PositiveOrZero Integer scorePoints,
        @PositiveOrZero Integer scoreAssists,
        @PositiveOrZero Integer scoreRebounds,

        // Provenance (docs/cardio/51 R8)
        /* MEASURED | MANUAL | DEVICE — a manual override always wins. */
        String distanceSource,
        String caloriesSource,

        // Route (docs/cardio/54-cardio-gps-route-plan.md)
        /* Encoded, simplified polyline; raw GPS points never leave the phone. */
        String routePolyline,
        @PositiveOrZero Integer routePointCount,

        // Hike (docs/cardio/60 C8.1)
        /* The one field only the user can know — refines the calorie estimate. */
        @PositiveOrZero Double backpackWeightKg,
        /* Grade-adjusted pace, computed client-side (docs/cardio/56-cardio-statistics-plan.md). */
        @PositiveOrZero Double avgGapSecondsPerKm,
        /* Manual weather snapshot (docs/cardio/60 Q-C8.1) — can be sub-zero, unconstrained. */
        Double weatherTempC,
        @PositiveOrZero Double weatherWindKph,
        @PositiveOrZero Double weatherPrecipMm,
        /* Free code (CLEAR | PARTLY_CLOUDY | CLOUDY | RAIN | SNOW | WINDY, ...); unconstrained, display only. */
        String weatherCondition
) {
}
