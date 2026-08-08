package com.lifey.chat.spi;

import java.util.Map;

/**
 * One notification, already written by the chat.
 *
 * @param data        deep-link payload carried through to the client untouched
 * @param collapseKey notifications sharing one replace each other in the OS
 *                    notification centre, so a thread occupies a single row
 *                    however many messages it sent (§5.3). Null stands alone.
 */
public record ChatPushNotification(
        String title,
        String body,
        Map<String, String> data,
        String collapseKey
) {
    public ChatPushNotification {
        data = Map.copyOf(data);
    }
}
