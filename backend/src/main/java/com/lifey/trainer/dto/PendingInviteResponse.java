package com.lifey.trainer.dto;

import java.time.Instant;

/** A pending invite as seen by the invited client (mobile floating card). */
public record PendingInviteResponse(
        Long id,
        String trainerEmail,
        Instant invitedAt,
        Instant expiresAt
) {
}
