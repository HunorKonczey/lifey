package com.lifey.internal.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.Map;

/**
 * Wire format of {@code POST /internal/push}. Mirrored by
 * {@code com.lifey.chat.spi.http.HttpChatPushSender} in the chat service — the
 * two records have to change together (§6.1).
 *
 * @param data        deep-link payload, passed through to the device untouched
 * @param collapseKey optional: notifications sharing one replace each other in
 *                    the OS notification centre
 */
public record InternalPushRequest(
        @NotNull Long userId,
        @NotBlank String title,
        @NotNull String body,
        Map<String, String> data,
        String collapseKey
) {
    public InternalPushRequest {
        data = data == null ? Map.of() : Map.copyOf(data);
    }
}
