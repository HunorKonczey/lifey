package com.lifey.chat.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/** Read up to and including this message; the server only ever moves the cursor forward. */
public record ReadReceiptRequest(@NotNull @Positive Long lastReadMessageId) {
}
