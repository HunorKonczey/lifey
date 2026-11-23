package com.lifey.workout.session;

/**
 * The {@code importSource} / {@code importAppName} / {@code healthWorkoutId}
 * combination on a {@code WorkoutSessionRequest} is not a valid import
 * (docs/integrations/89 D-G2, D-G3). These are cross-field rules that Bean
 * Validation can't express, so the service checks them. Mapped to 400.
 */
public class InvalidImportRequestException extends RuntimeException {

    public InvalidImportRequestException(String message) {
        super(message);
    }
}
