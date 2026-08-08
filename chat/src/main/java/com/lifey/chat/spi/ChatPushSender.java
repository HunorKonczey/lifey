package com.lifey.chat.spi;

/**
 * Delivery of a notification to whatever devices a user has registered.
 */
public interface ChatPushSender {

    /**
     * Fans the notification out to every registered device. <b>Never throws</b>:
     * a delivery problem is logged by the provider, and the §5.4 reminder job is
     * the chat's safety net for anything that did not land.
     */
    void send(Long userId, ChatPushNotification notification);

    /**
     * Whether the user can be reached by push at all. Only the email fallback
     * asks (§5.5) — it exists for the one case a push cannot cover, which is
     * having no device rather than having an unreachable one.
     */
    boolean hasRegisteredDevice(Long userId);
}
