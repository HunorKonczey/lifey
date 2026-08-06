package com.lifey.chat.entity;

import com.lifey.common.domain.BaseEntity;
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
 * One side of a conversation and everything that is per-viewer rather than
 * per-message: how far they have read, whether they muted the thread, when they
 * were last notified (docs/chat/40-trainer-chat-plan.md §3.1).
 *
 * <p>Exactly two rows exist per conversation, created together with it.
 */
@Getter
@Setter
@Entity
@Table(name = "chat_participants")
public class ChatParticipant extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "conversation_id", nullable = false)
    private ChatConversation conversation;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /**
     * Read cursor: everything up to and including this id is read. Advances
     * monotonically, so a late-arriving receipt can never un-read a thread.
     */
    @Column(name = "last_read_message_id")
    private Long lastReadMessageId;

    @Column(name = "last_read_at")
    private Instant lastReadAt;

    /** Maintained from I4 on, when the SSE stream can report actual delivery. */
    @Column(name = "last_delivered_message_id")
    private Long lastDeliveredMessageId;

    /** Per-thread mute, wired up in I5. */
    @Column(name = "muted_until")
    private Instant mutedUntil;

    /** Push coalescing window (§5.3), wired up in I5. */
    @Column(name = "last_notified_at")
    private Instant lastNotifiedAt;
}
