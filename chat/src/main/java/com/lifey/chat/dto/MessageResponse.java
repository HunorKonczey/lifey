package com.lifey.chat.dto;

import java.time.Instant;

/**
 * One message. Clients render the tombstone wording themselves rather than
 * receiving a server-side placeholder string, so it stays localizable.
 *
 * <p>Exactly one of three shapes: text, an image (with an optional caption in
 * {@code body}), or a tombstone. {@code body} and {@code attachment} are
 * therefore both null only when {@code deletedAt} is set — and deleting a
 * message with a picture really removes the picture too (§18.4/2).
 */
public record MessageResponse(
        Long id,
        Long conversationId,
        Long senderId,
        String body,
        String clientMessageId,
        Instant createdAt,
        Instant deletedAt,
        MessageAttachmentResponse attachment
) {
}
