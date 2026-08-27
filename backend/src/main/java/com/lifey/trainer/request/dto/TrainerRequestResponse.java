package com.lifey.trainer.request.dto;

import com.lifey.trainer.request.TrainerRequestStatus;

import java.time.Instant;

/** {@code GET /api/v1/trainer-requests/me} — lets the pending page poll its own status (66 §2). */
public record TrainerRequestResponse(
        Long id,
        TrainerRequestStatus status,
        String motivation,
        Integer clientCount,
        Instant createdAt,
        Instant decidedAt
) {
}
