package com.lifey.chat;

/**
 * Published when a participant's read cursor actually moved forward, so the
 * other side can turn their tick marks blue.
 *
 * <p>Only raised on a real advance: {@code markRead} is called on every scroll
 * to the bottom and is usually a no-op, and a frame per no-op would be pure
 * noise on the stream.
 *
 * <p>Consumed with {@code @TransactionalEventListener(AFTER_COMMIT)} for the
 * same reason as {@link ChatMessageStoredEvent}: never announce a cursor the
 * database has not accepted.
 */
public record ChatReadCursorEvent(Long conversationId, Long userId) {
}
