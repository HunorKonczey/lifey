package com.lifey.trainer.dto;

import java.time.Instant;

/**
 * A join link right after it was made: the only time its {@code token} is ever returned (only a hash is stored). The
 * web turns it into {@code <origin>/join/<token>}.
 */
public record CreatedTrainerInviteLinkResponse(
        Long id,
        String token,
        Instant createdAt,
        Instant expiresAt
) {
}
