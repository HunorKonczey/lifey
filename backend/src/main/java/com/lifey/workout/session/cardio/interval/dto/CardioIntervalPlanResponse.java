package com.lifey.workout.session.cardio.interval.dto;

import java.time.Instant;
import java.util.List;

/**
 * Response side of {@link CardioIntervalPlanRequest}. {@code updatedAt} /
 * {@code deletedAt} are the delta-sync fields (docs/16-delta-sync-rollout.md):
 * a non-null {@code deletedAt} on a row from the delta feed is a tombstone.
 *
 * <p>No total or hard-time here: both are a sum over {@link #steps()}, and
 * the editor recomputes them on every keystroke anyway (docs/cardio/61 §3 M37).
 */
public record CardioIntervalPlanResponse(
        Long id,
        String name,
        List<IntervalStepEntry> steps,
        Instant updatedAt,
        Instant deletedAt
) {
}
