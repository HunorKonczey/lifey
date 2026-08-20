package com.lifey.workout.session.cardio;

/**
 * The target effort of an interval section — a three-step scale
 * (könnyű · közepes · kemény), see docs/cardio/61 §3 M37 and §7.
 *
 * <p>Deliberately not a resistance level or a watt target: resistance runs on
 * a different scale on every machine, so a plan carrying it would not be
 * reusable, and most home machines report no power at all. A machine that
 * does report watts refines the label ("kemény · 200–230 W") rather than
 * replacing this scale.
 */
public enum IntervalIntensity {
    EASY,
    MODERATE,
    HARD
}
