package com.lifey.chat.repository;

import com.lifey.chat.entity.ChatParticipant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface ChatParticipantRepository extends JpaRepository<ChatParticipant, Long> {

    Optional<ChatParticipant> findByConversationIdAndUserId(Long conversationId, Long userId);

    /**
     * Every thread this user is in, with the conversation loaded — a stream
     * connect advances the delivered cursor across all of them at once
     * (see {@code ChatReceiptServiceImpl#markDeliveredOnConnect}).
     */
    @Query("select p from ChatParticipant p join fetch p.conversation where p.user.id = :userId")
    List<ChatParticipant> findAllForUser(@Param("userId") Long userId);

    /**
     * Both sides' rows for the given threads: the peer's carries the cursors
     * behind the viewer's tick marks, the viewer's own carries their mute.
     * Batched so the conversation list stays one query rather than two per row.
     */
    @Query("select p from ChatParticipant p join fetch p.conversation join fetch p.user "
            + "where p.conversation.id in :conversationIds")
    List<ChatParticipant> findAllForConversations(@Param("conversationIds") List<Long> conversationIds);

    /**
     * Reminder candidates (§5.4): participants holding a message that is still
     * unread and already older than the threshold.
     *
     * <p>The candidate set is small by construction — only threads that have
     * been sitting unread for half an hour — so the job resolves counts and
     * names per row afterwards rather than trying to express the whole
     * aggregation here.
     */
    @Query("""
            select p from ChatParticipant p
            join fetch p.conversation c
            join fetch p.user
            where exists (
                select 1 from ChatMessage m
                where m.conversation.id = c.id
                  and m.deletedAt is null
                  and m.sender.id <> p.user.id
                  and (p.lastReadMessageId is null or m.id > p.lastReadMessageId)
                  and m.createdAt < :threshold
            )
            """)
    List<ChatParticipant> findReminderCandidates(@Param("threshold") Instant threshold);
}
