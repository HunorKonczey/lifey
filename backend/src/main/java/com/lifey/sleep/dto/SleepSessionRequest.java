package com.lifey.sleep.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.time.Instant;

/**
 * A sleep session imported from the health store (docs/integrations/89 D-G7). The stage minutes are optional: a source
 * without stages sends only the start and end.
 */
public record SleepSessionRequest(

        @NotNull
        Instant startedAt,

        /** A session still running isn't imported, so the end is in the past. */
        @NotNull
        @PastOrPresent
        Instant endedAt,

        @PositiveOrZero
        Integer asleepMinutes,

        @PositiveOrZero
        Integer deepMinutes,

        @PositiveOrZero
        Integer lightMinutes,

        @PositiveOrZero
        Integer remMinutes,

        @PositiveOrZero
        Integer awakeMinutes,

        /** The writing app as the store reported it, e.g. "Garmin Connect". Blank is stored as none. */
        @Size(max = 64)
        String sourceAppName,

        /** The store's record id, the dedupe key: a second import of the same id is a 409. */
        @Size(max = 128)
        String healthRecordId
) {

    /** Mirrors {@code sleep_sessions_ended_after_started_ck}, so a bad pair is a 400 rather than a database error. */
    @JsonIgnore
    @AssertTrue(message = "must be after startedAt")
    public boolean isEndedAfterStarted() {
        return startedAt == null || endedAt == null || endedAt.isAfter(startedAt);
    }
}
