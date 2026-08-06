package com.lifey.chat.dto;

import java.time.Instant;

/**
 * One message. {@code body} is null exactly when {@code deletedAt} is set —
 * clients render the tombstone themselves rather than receiving a server-side
 * placeholder string, so the wording stays localizable.
 */
public record MessageResponse(
        Long id,
        Long conversationId,
        Long senderId,
        String body,
        String clientMessageId,
        Instant createdAt,
        Instant deletedAt
) {
}
