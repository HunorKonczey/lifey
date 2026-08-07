package com.lifey.chat.dto;

import java.time.Instant;

/**
 * Body of an {@code event: deleted} frame. The id and the timestamp are the
 * whole payload: the client already holds the row, and what changed about it is
 * precisely that the text is gone.
 */
public record MessageDeletedEventPayload(Long conversationId, Long messageId, Instant deletedAt) {
}
