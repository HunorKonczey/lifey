package com.lifey.clientconfig.dto;

/**
 * @param chatBaseUrl      full base URL of the chat API, including the
 *                         {@code /api/v1} prefix, e.g.
 *                         {@code https://lifey-chat.onrender.com/api/v1}.
 *                         <b>Empty means "use your own base URL"</b> — the chat
 *                         is served by this API.
 * @param configTtlSeconds how long a client may cache this response
 */
public record ClientConfigResponse(String chatBaseUrl, long configTtlSeconds) {
}
