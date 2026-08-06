package com.lifey.chat.repository;

import com.lifey.chat.entity.ChatMessage;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {

    /** Idempotency lookup for {@code POST /messages} (§4.2). */
    Optional<ChatMessage> findByConversationIdAndClientMessageId(Long conversationId, String clientMessageId);

    /** Keyset page walking backwards in time — the "scroll up for history" direction. */
    @Query("select m from ChatMessage m where m.conversation.id = :conversationId and m.id < :before order by m.id desc")
    List<ChatMessage> findPageBefore(@Param("conversationId") Long conversationId,
                                     @Param("before") Long before,
                                     Pageable pageable);

    /**
     * Keyset page walking forwards — gap filling after the client was offline
     * or lost its stream. Ascending so the page starts right above the cursor
     * instead of at the newest message.
     */
    @Query("select m from ChatMessage m where m.conversation.id = :conversationId and m.id > :after order by m.id asc")
    List<ChatMessage> findPageAfter(@Param("conversationId") Long conversationId,
                                    @Param("after") Long after,
                                    Pageable pageable);

    @Query("select m from ChatMessage m where m.conversation.id = :conversationId order by m.id desc")
    List<ChatMessage> findLatestPage(@Param("conversationId") Long conversationId, Pageable pageable);

    /**
     * Unread counts for every thread of one user in a single query — the
     * conversation list would otherwise be an N+1. Counts messages above the
     * viewer's read cursor that they did not send and that are not tombstoned.
     */
    @Query("select m.conversation.id as conversationId, count(m) as unreadCount from ChatMessage m "
            + "join ChatParticipant p on p.conversation.id = m.conversation.id and p.user.id = :userId "
            + "where m.deletedAt is null and m.sender.id <> :userId "
            + "and (p.lastReadMessageId is null or m.id > p.lastReadMessageId) "
            + "group by m.conversation.id")
    List<ConversationUnreadCount> countUnreadByConversation(@Param("userId") Long userId);

    /** Single-thread variant of {@link #countUnreadByConversation(Long)}. */
    @Query("select count(m) from ChatMessage m "
            + "join ChatParticipant p on p.conversation.id = m.conversation.id and p.user.id = :userId "
            + "where m.conversation.id = :conversationId and m.deletedAt is null and m.sender.id <> :userId "
            + "and (p.lastReadMessageId is null or m.id > p.lastReadMessageId)")
    long countUnread(@Param("conversationId") Long conversationId, @Param("userId") Long userId);
}
