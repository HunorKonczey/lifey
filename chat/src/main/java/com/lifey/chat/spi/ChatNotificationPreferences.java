package com.lifey.chat.spi;

/**
 * The recipient's notification settings, as the push ladder needs them.
 */
public interface ChatNotificationPreferences {

    /**
     * Never empty: a user with no settings row gets the defaults
     * (see {@link ChatPushPrefs}).
     */
    ChatPushPrefs load(Long userId);
}
