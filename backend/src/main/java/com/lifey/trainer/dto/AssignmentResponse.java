package com.lifey.trainer.dto;

import com.lifey.trainer.ContentType;

import java.time.Instant;

/**
 * @param previouslyAssigned whether this trainer had already assigned this exact
 *                            source to this client before — the assignment still
 *                            goes through (a fresh copy, not a version), this only
 *                            drives the "you've assigned this before" UI warning.
 */
public record AssignmentResponse(
        Long id,
        ContentType contentType,
        Long sourceId,
        Long copiedId,
        Instant assignedAt,
        boolean previouslyAssigned
) {
}
