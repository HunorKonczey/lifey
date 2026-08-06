package com.lifey.chat.service;

import com.lifey.chat.dto.ConversationListResponse;
import com.lifey.chat.dto.MessageListResponse;
import com.lifey.chat.dto.SendMessageRequest;

public interface ChatService {

    /** Every thread of the caller, newest activity first, regardless of role. */
    ConversationListResponse getConversations();

    /** Lazy-create by relationship id; {@code created} tells the controller 201 from 200. */
    OpenConversationResult openConversation(Long trainerClientId);

    /** Lazy-create by peer user id — same result, the entry point mobile has. */
    OpenConversationResult openConversationWithUser(Long peerUserId);

    /**
     * Keyset page. {@code before} walks into history, {@code after} fills a gap
     * above a known id; passing both is not meaningful and {@code after} wins.
     */
    MessageListResponse listMessages(Long conversationId, Long before, Long after, Integer limit);

    /** Idempotent on {@code clientMessageId}: a retry returns the stored message. */
    SendMessageResult sendMessage(Long conversationId, SendMessageRequest request);

    /** Advances the caller's read cursor; never moves it backwards. */
    void markRead(Long conversationId, Long lastReadMessageId);

    /** Tombstones one of the caller's own messages. */
    void deleteMessage(Long messageId);

    /** Closes the pair's live thread(s) for writing when the relationship ends. */
    void archiveForPair(Long trainerId, Long clientId);
}
