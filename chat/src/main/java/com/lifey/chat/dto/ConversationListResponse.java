package com.lifey.chat.dto;

import java.util.List;

/**
 * Wrapped rather than a bare array: v1 doesn't paginate the conversation list
 * (a trainer realistically has &lt; 100 clients), but the envelope leaves room
 * to add a cursor later without breaking clients (§4.1).
 */
public record ConversationListResponse(List<ConversationResponse> items) {
}
