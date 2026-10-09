package com.lifey.trainer.dto;

import java.time.Instant;

/** A live join link as the trainer lists it. The token is not part of it: it was shown once, when the link was made. */
public record TrainerInviteLinkResponse(
        Long id,
        Instant createdAt,
        Instant expiresAt
) {
}
