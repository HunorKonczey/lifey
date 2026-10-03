package com.lifey.trainer;

import java.time.Instant;

/**
 * What became of an invite the trainer sent (docs/redesign-web/82 section 2.2). Derived from the
 * {@code trainer_clients} row - nothing extra is stored: the row is never deleted, it only moves between
 * statuses with {@code responded_at} / {@code revoked_at} stamped.
 */
public enum InviteOutcome {
    PENDING, ACCEPTED, DECLINED, CANCELLED, EXPIRED;

    /**
     * @param respondedAt when the client answered; null while unanswered, and also null on an invite the trainer
     *                    withdrew, which is how a cancelled invite is told from a relationship that ended later
     */
    public static InviteOutcome of(TrainerClientStatus status, Instant respondedAt, Instant expiresAt, Instant now) {
        return switch (status) {
            case ACTIVE -> ACCEPTED;
            // REVOKED covers two things: a pending invite the trainer withdrew (never answered), and an accepted
            // relationship that was later ended by either side (answered).
            case REVOKED -> respondedAt != null ? ACCEPTED : CANCELLED;
            case DECLINED -> DECLINED;
            case EXPIRED -> EXPIRED;
            // The nightly sweep flips PENDING to EXPIRED once a day, so a PENDING row past its window is expired already.
            case PENDING -> expiresAt.isAfter(now) ? PENDING : EXPIRED;
        };
    }
}
