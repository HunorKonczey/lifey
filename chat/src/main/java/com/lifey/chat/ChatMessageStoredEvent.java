package com.lifey.chat;

/**
 * Published once a chat message is committed. Deliberately carries only the
 * id: the notification listener re-reads what it needs, so the message text
 * never travels inside an object that a framework might log
 * (docs/chat/40-trainer-chat-plan.md §7.4 — message bodies never reach logs).
 *
 * <p>Consumed with {@code @TransactionalEventListener(AFTER_COMMIT)} so a push
 * failure can never roll back the message, and so we never push about a
 * message that was never stored (§5.2).
 */
public record ChatMessageStoredEvent(Long messageId) {
}
