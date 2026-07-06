package com.lifey.trainer.dto;

import java.time.Instant;

/** A pending invite as seen by the trainer who sent it. */
public record TrainerInviteResponse(
        Long id,
        String clientEmail,
        Instant createdAt,
        Instant expiresAt
) {
}
