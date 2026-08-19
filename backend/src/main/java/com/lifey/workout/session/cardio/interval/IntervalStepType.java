package com.lifey.workout.session.cardio.interval;

/**
 * Whether a {@link CardioIntervalStep} row is a section or the repeat block
 * that holds sections — see docs/cardio/61 §3 M37, where a plan is a flat
 * list of exactly these two kinds of item.
 */
public enum IntervalStepType {
    /** A duration at a target intensity. */
    STEP,

    /** "4× (4:00 kemény + 3:00 könnyű)" — repeats its child steps. Never nested. */
    REPEAT
}
