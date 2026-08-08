package com.lifey.chat.entity;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * A 1:1 thread bound to exactly one trainer-client relationship
 * (docs/chat/40-trainer-chat-plan.md §3.1). {@code trainerId}/{@code clientId}
 * are denormalized off the relationship so every participant check and every
 * list query stays a single-table read — the relationship itself is only needed
 * when opening the thread.
 *
 * <p>Access is never decided by role: a caller is authorized iff they are the
 * trainer or the client of this conversation (§4).
 *
 * <p><b>Ids, not relations.</b> The three columns below point at rows the chat
 * does not own ({@code trainer_clients}, {@code users}), and are held as plain
 * ids rather than {@code @ManyToOne} associations — the chat resolves the people
 * behind them through {@code com.lifey.chat.spi}, never by navigating into
 * another module's entity graph
 * (docs/chat/44-chat-service-extraction-plan.md §2.4). The foreign keys are
 * still enforced by the database (V64__chat.sql).
 */
@Getter
@Setter
@Entity
@Table(name = "chat_conversations")
public class ChatConversation extends BaseEntity {

    @Column(name = "trainer_client_id", nullable = false)
    private Long trainerClientId;

    @Column(name = "trainer_id", nullable = false)
    private Long trainerId;

    @Column(name = "client_id", nullable = false)
    private Long clientId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    /** Sort key for the conversation list; null until the first message. */
    @Column(name = "last_message_at")
    private Instant lastMessageAt;

    /**
     * Preview pointer for the conversation list, and the ceiling a read receipt
     * is clamped to. Not mapped as a relation — see V64__chat.sql.
     */
    @Column(name = "last_message_id")
    private Long lastMessageId;

    /**
     * Set when the underlying relationship is revoked (see
     * {@code ChatArchiveListener}). An archived thread stays readable forever
     * but rejects new messages with 409 (§1.3/1).
     */
    @Column(name = "archived_at")
    private Instant archivedAt;

    /** The other side of the thread from {@code viewerId}. */
    public Long peerOf(Long viewerId) {
        return trainerId.equals(viewerId) ? clientId : trainerId;
    }

    public boolean hasParticipant(Long userId) {
        return trainerId.equals(userId) || clientId.equals(userId);
    }
}
