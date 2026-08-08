package com.lifey.chat.service;

import com.lifey.chat.dto.ChatEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * Single-instance fan-out: the recipient's connections, if any, are on this
 * JVM, so there is nothing to route.
 *
 * <p><b>What happens on more than one instance:</b> chat keeps working, but
 * realtime becomes instance-local — a message only streams to clients that
 * happen to be connected to the same node as the sender. Everyone else still
 * gets it through the push notification and the reload on focus, because the
 * stream is never the source of truth (§4.4). Replacing this class with a
 * {@code LISTEN/NOTIFY} implementation is the fix (§9 / I7), and it needs no
 * change anywhere else.
 */
@Service
@RequiredArgsConstructor
public class InMemoryChatEventBus implements ChatEventBus {

    private final ChatEmitterRegistry registry;

    @Override
    public boolean publish(Long userId, ChatEvent event) {
        return registry.send(userId, event);
    }

    @Override
    public boolean isConnected(Long userId) {
        return registry.isConnected(userId);
    }
}
