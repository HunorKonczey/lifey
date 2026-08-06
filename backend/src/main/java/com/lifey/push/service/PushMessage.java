package com.lifey.push.service;

import java.util.Map;

/**
 * Platform-agnostic notification content. {@code data} is a deep-link
 * payload (e.g. {@code type=scheduled_workout}, {@code sessionId=...}) —
 * never rendered directly, just carried through to the client.
 *
 * @param collapseKey optional: notifications sharing one are folded into a
 *                    single row by the OS, so five messages in one chat thread
 *                    replace each other instead of stacking up
 *                    (docs/chat/40-trainer-chat-plan.md §5.3). Null means "this
 *                    notification stands on its own", which is right for
 *                    one-off events like a workout reminder.
 */
public record PushMessage(
        String title,
        String body,
        Map<String, String> data,
        String collapseKey
) {
    public PushMessage {
        data = Map.copyOf(data);
    }

    /** A notification that should not be folded together with any other. */
    public PushMessage(String title, String body, Map<String, String> data) {
        this(title, body, data, null);
    }
}
