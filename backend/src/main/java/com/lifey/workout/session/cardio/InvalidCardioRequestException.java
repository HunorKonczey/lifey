package com.lifey.workout.session.cardio;

/**
 * The {@code sessionKind}/{@code activityType}/{@code cardio}/{@code splits}
 * combination on a {@code WorkoutSessionRequest} violates the discriminator
 * invariant the {@code workout_sessions_kind_activity_ck} DB constraint also
 * enforces (docs/cardio/52-cardio-domain-backend-plan.md §3.2) — cross-field,
 * so Bean Validation can't express it; checked in the service instead.
 */
public class InvalidCardioRequestException extends RuntimeException {

    public InvalidCardioRequestException(String message) {
        super(message);
    }
}
