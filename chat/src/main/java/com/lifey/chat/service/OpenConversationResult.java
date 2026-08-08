package com.lifey.chat.service;

import com.lifey.chat.dto.ConversationResponse;

/**
 * Opening a conversation is lazy-create, so the caller needs to know whether it
 * already existed (200) or was just created (201). Never leaves the process —
 * hence a service-layer record rather than a DTO.
 */
public record OpenConversationResult(ConversationResponse conversation, boolean created) {
}
