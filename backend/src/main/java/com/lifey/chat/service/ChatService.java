package com.lifey.chat.service;

import com.lifey.chat.dto.ConversationListResponse;
import com.lifey.chat.dto.MessageListResponse;
import com.lifey.chat.dto.SendMessageRequest;
import com.lifey.chat.entity.ChatMessageAttachment;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;

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

    /**
     * Free-text search inside one thread, newest match first, keyset-paged by
     * {@code before} exactly like {@link #listMessages}.
     *
     * <p>A blank or too-short term is an empty result, not an error: the
     * clients search as you type, and answering the first keystroke with a 400
     * would turn normal use into a stream of failures.
     */
    MessageListResponse searchMessages(Long conversationId, String query, Long before, Integer limit);

    /** Idempotent on {@code clientMessageId}: a retry returns the stored message. */
    SendMessageResult sendMessage(Long conversationId, SendMessageRequest request);

    /**
     * The same send, with an image. One request rather than "create the message,
     * then attach": a two-step upload can leave an empty bubble on the other
     * side when the second call never lands, and it would need its own
     * idempotency story on top of {@code clientMessageId} (§18.4/1).
     *
     * @param body optional caption — an image on its own is a complete message
     */
    SendMessageResult sendMessage(Long conversationId, String body, String clientMessageId, MultipartFile image);

    /**
     * The stored image of a message in one of the caller's own threads.
     * Non-participants get a 404, exactly like every other chat route: the
     * permission follows the conversation, never the message id (§4).
     */
    ChatMessageAttachment findAttachment(Long messageId);

    /** Advances the caller's read cursor; never moves it backwards. */
    void markRead(Long conversationId, Long lastReadMessageId);

    /** Tombstones one of the caller's own messages. */
    void deleteMessage(Long messageId);

    /**
     * Silences this thread's pushes for the caller until {@code mutedUntil};
     * null unmutes. Only the notification is affected — messages still arrive
     * and still count as unread (§I5).
     */
    void mute(Long conversationId, Instant mutedUntil);

    /** Closes the pair's live thread(s) for writing when the relationship ends. */
    void archiveForPair(Long trainerId, Long clientId);
}
