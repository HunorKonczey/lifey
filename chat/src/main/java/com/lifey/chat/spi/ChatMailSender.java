package com.lifey.chat.spi;

/**
 * The §5.5 email fallback: a last-resort nudge for someone with no push device
 * at all. Behind {@code lifey.chat.email-fallback-enabled}, off by default.
 */
public interface ChatMailSender {

    void sendUnreadChatEmail(Long userId, long unreadCount, String peerName);
}
