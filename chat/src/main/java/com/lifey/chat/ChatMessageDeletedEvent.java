package com.lifey.chat;

/**
 * Published once a message has been tombstoned. Carries only the id, for the
 * same reason as {@link ChatMessageStoredEvent}: the body must never travel
 * inside an object a framework might log (§7.4) — and by this point there is
 * no body left to carry anyway.
 *
 * <p>A deletion is the one chat write that changes a row the other side may
 * already be showing. The gap-fill on reconnect only ever walks *forward*
 * ({@code after=<id>}), so without a frame of its own a tombstone would stay
 * invisible to the peer until their cache was dropped — the limitation the
 * plan records in §14.3.
 *
 * <p>Consumed with {@code @TransactionalEventListener(AFTER_COMMIT)}: never
 * announce a deletion the database has not accepted.
 */
public record ChatMessageDeletedEvent(Long messageId) {
}
