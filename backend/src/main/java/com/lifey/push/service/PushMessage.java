package com.lifey.push.service;

import java.util.Map;

/**
 * Platform-agnostic notification content. {@code data} is a deep-link
 * payload (e.g. {@code type=scheduled_workout}, {@code sessionId=...}) —
 * never rendered directly, just carried through to the client.
 */
public record PushMessage(
        String title,
        String body,
        Map<String, String> data
) {
    public PushMessage {
        data = Map.copyOf(data);
    }
}
