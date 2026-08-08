package com.lifey.chat.service;

import com.lifey.chat.dto.ChatEvent;

/**
 * How a chat event reaches a user's live clients. The scaling seam from §2:
 * v1 hands the event straight to this instance's {@link ChatEmitterRegistry};
 * a multi-instance deployment swaps in a Postgres {@code LISTEN/NOTIFY} (or
 * Redis) implementation that fans the event out to every instance, each of
 * which then writes to its own local emitters.
 *
 * <p>Nothing above this interface knows which one is in play, and the domain
 * and notification logic never change when it is replaced.
 */
public interface ChatEventBus {

    /**
     * Deliver to one user's clients, wherever they are connected.
     *
     * @return true if the event reached a live connection <em>now</em>. Callers
     * treat false as "not delivered", which is exactly the input the push
     * decision needs (§5.1) — a lie in the optimistic direction would cost the
     * recipient a notification.
     */
    boolean publish(Long userId, ChatEvent event);

    /** Whether the user has any live client at all, regardless of thread. */
    boolean isConnected(Long userId);
}
