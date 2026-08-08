package com.lifey.chat.dto;

/**
 * What a client knows about a message's image without downloading it: enough to
 * reserve the right box in the thread and to decide whether to fetch it at all.
 * The bytes come from {@code GET /chat/messages/{id}/attachment}.
 */
public record MessageAttachmentResponse(int width, int height, int byteSize) {
}
