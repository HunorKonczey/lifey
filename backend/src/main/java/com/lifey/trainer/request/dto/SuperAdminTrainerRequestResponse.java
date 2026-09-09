package com.lifey.trainer.request.dto;

import com.lifey.trainer.request.TrainerRequestStatus;

import java.time.Instant;

/** {@code GET /api/v1/superadmin/trainer-requests} — the review queue (66 §2). */
public record SuperAdminTrainerRequestResponse(
        Long id,
        Long userId,
        String userEmail,
        TrainerRequestStatus status,
        String motivation,
        Integer clientCount,
        String signupSource,
        Instant createdAt,
        Instant decidedAt
) {
}
