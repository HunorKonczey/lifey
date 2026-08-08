package com.lifey.chat.dto;

import jakarta.validation.constraints.NotNull;

/** "I am writing in this thread." Fire and forget — the answer is 204. */
public record TypingRequest(@NotNull Long conversationId) {
}
