package com.lifey.chat.service;

/**
 * Owns the two per-participant cursors that drive the sender's tick marks —
 * "delivered" and "read" — and the {@code read} frames that carry them to the
 * other side (§4.4, §I4).
 *
 * <p>Both cursors only ever move forward, so every method here is safe to call
 * with a stale or racing value: the older one is simply ignored.
 */
public interface ChatReceiptService {

    /**
     * A client of this user just opened a stream, so everything stored up to
     * now has reached them: advance the delivered cursor in every thread.
     *
     * <p>This is the coarse version on purpose. Tracking delivery per message
     * would need an ack from the client for each one; "your client is live, and
     * whatever it does not already have it is about to load" is true within the
     * reconnect window and costs one pass over the user's threads.
     */
    void markDeliveredOnConnect(Long userId);

    /** The message was written to a live connection of this user. */
    void recordDelivered(Long conversationId, Long userId, Long messageId);

    /**
     * The user was looking at this very thread when the message arrived (§5.1),
     * so it is read on arrival — read implies delivered, and both advance.
     */
    void recordSeen(Long conversationId, Long userId, Long messageId);

    /** Send this user's cursors to the other participant as a {@code read} frame. */
    void broadcastCursors(Long conversationId, Long userId);
}
