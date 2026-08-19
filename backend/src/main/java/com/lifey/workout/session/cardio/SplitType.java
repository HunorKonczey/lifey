package com.lifey.workout.session.cardio;

/**
 * What a {@link CardioSplit} row measures — see docs/cardio/60 D-C7.1. The
 * execution of an interval plan doesn't get a table of its own: it lands in
 * {@code cardio_splits} next to the running splits, told apart by this.
 */
public enum SplitType {
    /** A per-km/lap split of a DISTANCE-family session (the original, V68). */
    DISTANCE,

    /** One executed section of an interval plan on the indoor bike (V70). */
    INTERVAL
}
