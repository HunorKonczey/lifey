package com.lifey.chat.spi.http;

import com.lifey.chat.spi.ChatMailSender;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * The §5.5 email fallback, deliberately not carried across (§6.3).
 *
 * <p>The code was complete in the monolith but the flag
 * ({@code lifey.chat.email-fallback-enabled}) has been {@code false} since it
 * was written, and it has <b>never run in production</b>. Building an HTTP path
 * for it here would mean adding a mail endpoint to the monolith, a wire format
 * and a failure mode — all for a feature nobody has yet decided to turn on.
 *
 * <p>The flag stays off, so this is unreachable. It logs rather than throwing so
 * that turning the flag on by accident degrades to "no email" instead of taking
 * the reminder sweep down with it.
 *
 * <p>To actually enable it: a generic {@code POST /internal/mail/send} on the
 * monolith taking {@code {userId, subject, body}}, with the copy rendered here —
 * the chat owns its own wording.
 */
@Slf4j
@Component
class NoopChatMailSender implements ChatMailSender {

    @Override
    public void sendUnreadChatEmail(Long userId, long unreadCount, String peerName) {
        log.warn("Chat email fallback is not implemented in the chat service; "
                + "skipping unread email for user {} ({} unread). See plan §6.3.", userId, unreadCount);
    }
}
