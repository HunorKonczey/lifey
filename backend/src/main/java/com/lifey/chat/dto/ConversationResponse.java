package com.lifey.chat.dto;

import java.time.Instant;

/**
 * A conversation row as the caller sees it. {@code lastMessage} reuses the full
 * {@link MessageResponse} shape rather than a trimmed preview record so clients
 * parse a single message type everywhere; it is null until the first message.
 */
public record ConversationResponse(
        Long id,
        ChatPeerResponse peer,
        MessageResponse lastMessage,
        long unreadCount,
        Instant archivedAt
) {
}
