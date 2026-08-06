package com.lifey.chat.entity;

import com.lifey.common.domain.BaseEntity;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * A 1:1 thread bound to exactly one trainer-client relationship
 * (docs/chat/40-trainer-chat-plan.md §3.1). {@code trainer}/{@code client} are
 * denormalized off {@link TrainerClient} so every participant check and every
 * list query stays a single-table read — the relationship row is only needed
 * when opening the thread.
 *
 * <p>Access is never decided by role: a caller is authorized iff they are the
 * trainer or the client of this conversation (§4).
 */
@Getter
@Setter
@Entity
@Table(name = "chat_conversations")
public class ChatConversation extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trainer_client_id", nullable = false)
    private TrainerClient trainerClient;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trainer_id", nullable = false)
    private User trainer;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "client_id", nullable = false)
    private User client;

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
}
