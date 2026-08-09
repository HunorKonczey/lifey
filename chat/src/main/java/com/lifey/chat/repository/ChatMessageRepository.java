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
     * Free-text search inside one thread (§20), keyset-paged the same way the
     * thread itself is so "more results" is the same mechanic as "more history".
     *
     * <p>Accent-insensitive on top of case-insensitive via Postgres'
     * {@code unaccent}, exactly as {@code FoodRepository} does it — in Hungarian
     * a search for "labnap" has to find "lábnap", or the feature is a toy. The
     * {@code function()} passthrough keeps this a JPQL query over entity paths
     * rather than a native one.
     *
     * <p>{@code escape '!'} because the caller's text is a search term, not a
     * pattern: someone looking for "50%" must not match every message. The
     * service escapes {@code !}, {@code %} and {@code _} before binding.
     *
     * <p>Tombstones are excluded: their text is genuinely gone, so there is
     * nothing to match and a hit would be a hit on nothing.
     */
    @Query("select m from ChatMessage m "
            + "where m.conversation.id = :conversationId "
            + "and m.deletedAt is null and m.body is not null "
            + "and (:before is null or m.id < :before) "
            + "and cast(function('unaccent', lower(m.body)) as string) "
            + "like cast(function('unaccent', lower(:pattern)) as string) escape '!' "
            + "order by m.id desc")
    List<ChatMessage> searchInConversation(@Param("conversationId") Long conversationId,
                                           @Param("pattern") String pattern,
                                           @Param("before") Long before,
                                           Pageable pageable);

    /**
     * Everything the user missed since {@code after}, across all of their
     * threads at once — the {@code Last-Event-ID} replay when a stream
     * reconnects (§4.4). Ascending, so replayed frames arrive in the same order
     * they originally would have.
     */
    @Query("select m from ChatMessage m "
            + "join fetch m.conversation c "
            + "where (c.trainerId = :userId or c.clientId = :userId) and m.id > :after "
            + "order by m.id asc")
    List<ChatMessage> findAllForParticipantAfter(@Param("userId") Long userId,
                                                 @Param("after") Long after,
                                                 Pageable pageable);

    /**
     * Tombstones the client cannot learn about any other way: messages it
     * already holds ({@code id <= :upTo}, i.e. at or below its stream cursor)
     * that were deleted recently.
     *
     * <p>{@link #findAllForParticipantAfter} only walks forward, which is
     * exactly right for messages — they are immutable once sent — and exactly
     * wrong for the one write that reaches back into an existing row. Newer
     * deletions need no help: those rows are replayed as {@code message}
     * frames, and a replayed message carries its own {@code deletedAt}.
     */
    @Query("select m from ChatMessage m "
            + "join fetch m.conversation c "
            + "where (c.trainerId = :userId or c.clientId = :userId) "
            + "and m.id <= :upTo and m.deletedAt is not null and m.deletedAt > :since "
            + "order by m.id asc")
    List<ChatMessage> findTombstonesForParticipantUpTo(@Param("userId") Long userId,
                                                       @Param("upTo") Long upTo,
                                                       @Param("since") java.time.Instant since,
                                                       Pageable pageable);

    /**
     * Unread counts for every thread of one user in a single query — the
     * conversation list would otherwise be an N+1. Counts messages above the
     * viewer's read cursor that they did not send and that are not tombstoned.
     */
    @Query("select m.conversation.id as conversationId, count(m) as unreadCount from ChatMessage m "
            + "join ChatParticipant p on p.conversation.id = m.conversation.id and p.userId = :userId "
            + "where m.deletedAt is null and m.senderId <> :userId "
            + "and (p.lastReadMessageId is null or m.id > p.lastReadMessageId) "
            + "group by m.conversation.id")
    List<ConversationUnreadCount> countUnreadByConversation(@Param("userId") Long userId);

    /** Single-thread variant of {@link #countUnreadByConversation(Long)}. */
    @Query("select count(m) from ChatMessage m "
            + "join ChatParticipant p on p.conversation.id = m.conversation.id and p.userId = :userId "
            + "where m.conversation.id = :conversationId and m.deletedAt is null and m.senderId <> :userId "
            + "and (p.lastReadMessageId is null or m.id > p.lastReadMessageId)")
    long countUnread(@Param("conversationId") Long conversationId, @Param("userId") Long userId);
}
