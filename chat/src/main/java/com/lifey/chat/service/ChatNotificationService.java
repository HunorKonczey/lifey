package com.lifey.chat.service;

import com.lifey.chat.ChatMessageStoredEvent;

public interface ChatNotificationService {

    /**
     * Decides whether the recipient needs a push about a just-stored message,
     * and sends it. Never throws — a notification problem must not surface as
     * a failed send (docs/chat/40-trainer-chat-plan.md §5.2).
     */
    void onMessageStored(ChatMessageStoredEvent event);
}
