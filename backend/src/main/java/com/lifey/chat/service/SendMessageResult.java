package com.lifey.chat.service;

import com.lifey.chat.dto.MessageResponse;

/**
 * {@code created} is false when the send was an idempotent replay of a
 * {@code clientMessageId} we already stored — 200 rather than 201, so a
 * retrying client can tell "already landed" from "just landed".
 */
public record SendMessageResult(MessageResponse message, boolean created) {
}
