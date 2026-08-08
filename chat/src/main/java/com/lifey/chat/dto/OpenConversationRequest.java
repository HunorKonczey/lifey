package com.lifey.chat.dto;

import jakarta.validation.constraints.NotNull;

/**
 * The web entry point, which already holds the relationship id from the client
 * detail page. Mobile knows the peer's user id instead and uses
 * {@code POST /chat/conversations/with-user/{userId}} (§4.1).
 */
public record OpenConversationRequest(@NotNull Long trainerClientId) {
}
