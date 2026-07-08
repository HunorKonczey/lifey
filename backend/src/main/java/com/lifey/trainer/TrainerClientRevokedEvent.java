package com.lifey.trainer;

/**
 * Published whenever a trainer-client relationship moves to REVOKED — either
 * side can trigger this (trainer removes the client, or the client leaves).
 * Consumed synchronously in the same transaction (see
 * {@code ScheduleCancellationListener}) so the schedule cancellation is part
 * of the same atomic revoke.
 */
public record TrainerClientRevokedEvent(Long trainerId, Long clientId) {
}
