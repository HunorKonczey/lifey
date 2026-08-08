package com.lifey.chat.dto;

import java.time.Instant;

/**
 * A conversation row as the caller sees it. {@code lastMessage} reuses the full
 * {@link MessageResponse} shape rather than a trimmed preview record so clients
 * parse a single message type everywhere; it is null until the first message.
 *
 * <p>The two peer cursors are what the sender's tick marks are made of: a
 * message id at or below {@code peerLastReadMessageId} is read, at or below
 * {@code peerLastDeliveredMessageId} is delivered, anything above is merely
 * sent. They live on the conversation rather than on each message because the
 * cursors are per participant, not per message (§3.1) — one pair of numbers
 * decorates the whole thread. Live updates arrive as {@code read} frames on the
 * stream (§4.4); this is the value a client starts from.
 *
 * <p>{@code mutedUntil} is the caller's <em>own</em> setting, not the peer's —
 * the one per-participant field here that describes the viewer rather than the
 * other side. Null (or a past instant) means the thread is not muted.
 */
public record ConversationResponse(
        Long id,
        ChatPeerResponse peer,
        MessageResponse lastMessage,
        long unreadCount,
        Instant archivedAt,
        Long peerLastDeliveredMessageId,
        Long peerLastReadMessageId,
        Instant mutedUntil
) {
}
