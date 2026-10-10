package com.lifey.chat.dto;

/**
 * Body of an {@code event: online} frame - "this person of yours opened (or closed) the app" (LIF-122,
 * docs/chat/40-trainer-chat-plan.md section 22).
 *
 * <p>Sent only to the people who share an open thread with {@code userId}, and only about being connected: no "last seen",
 * no thread, no time. Like the typing hint it is not stored and has no REST counterpart - a client that missed it learns the
 * current state from the frames the server sends on every (re)connect.
 */
public record OnlineEventPayload(Long userId, boolean online) {
}
