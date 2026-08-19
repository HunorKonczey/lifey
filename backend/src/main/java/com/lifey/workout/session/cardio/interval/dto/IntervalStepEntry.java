package com.lifey.workout.session.cardio.interval.dto;

import com.lifey.workout.session.cardio.IntervalIntensity;
import com.lifey.workout.session.cardio.interval.IntervalStepType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * One item of an interval plan, in the tree shape the editor works in
 * (docs/cardio/61 §3 M37): a {@code STEP} is a duration at a target
 * intensity, a {@code REPEAT} carries a count and the steps it repeats in
 * {@link #children()}.
 *
 * <p>Which fields a given {@code type} may carry is cross-field, so the
 * service checks it (see {@code InvalidCardioRequestException}), mirroring
 * the {@code cardio_interval_steps_shape_ck} DB constraint — the annotations
 * here only constrain each field on its own.
 */
public record IntervalStepEntry(

        @NotNull
        IntervalStepType type,

        /* "Bemelegítés" — optional; without it the intensity label carries the meaning. */
        @Size(max = 60)
        String name,

        /* STEP only. */
        IntervalIntensity intensity,

        /* STEP only. */
        @Positive
        Integer durationSeconds,

        /* REPEAT only. */
        @Min(1)
        @Max(99)
        Integer repeatCount,

        /* REPEAT only, and never empty there. Nesting is one level deep: a child is always a STEP. */
        List<@Valid IntervalStepEntry> children
) {
}
