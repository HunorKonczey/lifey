package com.lifey.chat.repository;

import com.lifey.chat.entity.ChatConversation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ChatConversationRepository extends JpaRepository<ChatConversation, Long> {

    /**
     * Every thread the user takes part in, role-agnostic — a trainer who also
     * has their own trainer sees both in one list (§6.1). Both peers are
     * fetched eagerly: the list renders each one's display name, so a lazy
     * proxy here would be an N+1 per row.
     */
    @Query("select c from ChatConversation c "
            + "join fetch c.trainer "
            + "join fetch c.client "
            + "where c.trainer.id = :userId or c.client.id = :userId "
            + "order by c.lastMessageAt desc nulls last, c.id desc")
    List<ChatConversation> findAllForParticipant(@Param("userId") Long userId);

    /**
     * The participant guard behind every conversation-scoped endpoint: a
     * non-participant gets an empty Optional and therefore a 404, never a 403 —
     * we don't leak whether the thread exists (§4).
     */
    @Query("select c from ChatConversation c "
            + "join fetch c.trainer "
            + "join fetch c.client "
            + "where c.id = :id and (c.trainer.id = :userId or c.client.id = :userId)")
    Optional<ChatConversation> findByIdForParticipant(@Param("id") Long id, @Param("userId") Long userId);

    Optional<ChatConversation> findByTrainerClientId(Long trainerClientId);

    /**
     * A pair can hold more than one thread over time (revoke, then re-invite →
     * a new trainer_clients row → a new conversation), so this returns a list
     * even though only one of them is ever live.
     */
    List<ChatConversation> findByTrainerIdAndClientIdAndArchivedAtIsNull(Long trainerId, Long clientId);
}
