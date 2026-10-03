package com.lifey.chat.dto;

import java.time.Instant;

/**
 * One message. Clients render the tombstone wording themselves rather than
 * receiving a server-side placeholder string, so it stays localizable.
 *
 * <p>Exactly one of four shapes: text, an image (with an optional caption in
 * {@code body}), a result card (same optional caption), or a tombstone.
 * {@code body}, {@code attachment} and {@code card} are therefore all null only
 * when {@code deletedAt} is set — and deleting a message with a picture or a
 * card really removes it too (§18.4/2, docs/chat/83-chat-result-card-plan.md
 * §8 risk 3).
 */
public record MessageResponse(
        Long id,
        Long conversationId,
        Long senderId,
        String body,
        String clientMessageId,
        Instant createdAt,
        Instant deletedAt,
        MessageAttachmentResponse attachment,
        MessageCard card
) {
}
