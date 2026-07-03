package com.lifey.trainer.dto;

import com.lifey.trainer.ContentType;

import java.time.Instant;

/** One row of a trainer's "kiosztott tervek" view for a given client. */
public record AssignmentListItemResponse(
        Long id,
        ContentType contentType,
        Long sourceId,
        Long copiedId,
        Instant assignedAt
) {
}
