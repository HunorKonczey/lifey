package com.lifey.trainer.dto;

import java.time.Instant;
import java.util.List;

/**
 * Outcome of a bulk assignment, per group: {@code assignments} lists the
 * clients who received a fresh copy, {@code skippedClientIds} the clients who
 * already held this content (a skip, not an error — retries are idempotent).
 */
public record BulkAssignmentResponse(
        List<BulkAssignmentItem> assignments,
        List<Long> skippedClientIds
) {

    public record BulkAssignmentItem(
            Long clientId,
            Long assignmentId,
            Long copiedId,
            Instant assignedAt
    ) {
    }
}
