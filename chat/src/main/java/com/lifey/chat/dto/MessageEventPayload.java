package com.lifey.chat.dto;

/**
 * Body of an {@code event: message} frame. Carries the whole
 * {@link MessageResponse} rather than an id so a client that is already showing
 * the thread never has to make a round trip to render the bubble.
 */
public record MessageEventPayload(Long conversationId, MessageResponse message) {
}
