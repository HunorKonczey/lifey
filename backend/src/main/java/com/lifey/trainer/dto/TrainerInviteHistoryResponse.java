package com.lifey.trainer.dto;

import com.lifey.trainer.InviteOutcome;

import java.time.Instant;

/**
 * One invite the trainer sent, with how it ended. {@code endedAt} is when a REVOKED row stopped being live: the moment a
 * {@code CANCELLED} invite was withdrawn, or the moment an {@code ACCEPTED} relationship was later torn down (the answer
 * itself is {@code respondedAt}). Null for every other outcome.
 */
public record TrainerInviteHistoryResponse(
        Long id,
        String clientEmail,
        InviteOutcome outcome,
        Instant createdAt,
        Instant expiresAt,
        Instant respondedAt,
        Instant endedAt
) {
}
