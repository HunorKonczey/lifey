package com.lifey.chat.dto;

/**
 * Body of an {@code event: typing} frame — "the other person is writing".
 *
 * <p>Carries no name: the only surface that renders this is a thread the
 * recipient already has open, and that screen knows who the peer is. Sending a
 * display name would be duplicating what the conversation already says.
 *
 * <p>Nothing here is stored anywhere. The frame expires on its own after
 * {@code lifey.chat.typing-ttl} on the client, which is why this is the one
 * event with no REST counterpart (see the plan §19.4/1).
 */
public record TypingEventPayload(Long conversationId, Long userId) {
}
