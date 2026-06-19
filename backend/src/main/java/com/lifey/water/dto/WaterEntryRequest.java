package com.lifey.water.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Positive;

import java.time.Instant;

public record WaterEntryRequest(

        @NotNull
        @PastOrPresent
        Instant consumedAt,

        /**
         * Optional reference to the {@code WaterSource} used, purely informational
         * (e.g. to show its name/icon in history). The client resolves the volume
         * itself — picking a source pre-fills {@link #volumeLiters} with its preset
         * value, which the user can still adjust before logging (e.g. didn't finish
         * the bottle) — so the server trusts whatever volume is sent here.
         */
        Long sourceId,

        @NotNull
        @Positive
        Double volumeLiters
) {
}
