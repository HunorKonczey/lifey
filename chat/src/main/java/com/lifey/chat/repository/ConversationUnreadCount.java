package com.lifey.chat.repository;

/** Projection for {@link ChatMessageRepository#countUnreadByConversation(Long)}. */
public interface ConversationUnreadCount {

    Long getConversationId();

    long getUnreadCount();
}
