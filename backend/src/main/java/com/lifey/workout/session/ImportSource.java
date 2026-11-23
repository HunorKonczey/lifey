package com.lifey.workout.session;

/**
 * Where an imported {@link WorkoutSession} came from. Null on the session
 * means it was recorded in Lifey itself. See
 * docs/integrations/89-garmin-health-data-plan.md D-G2.
 */
public enum ImportSource {
    /** Read on the phone from Apple Health / Health Connect (plan 89 M1). */
    HEALTH,
    /** Delivered server-side by the Garmin Connect API (plan 89 M4); never accepted from a client. */
    GARMIN
}
