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

    /**
     * Per-thread mute (§I5). Null or in the past means "not muted"; the value
     * is an absolute instant rather than a duration so the mute expires on its
     * own without anything having to sweep it.
     */
    @Column(name = "muted_until")
    private Instant mutedUntil;

    /**
     * When this participant was last pushed about this thread — the coalescing
     * window (§5.3). Also what the reminder job compares against to tell
     * "never notified" from "notified but it didn't land".
     */
    @Column(name = "last_notified_at")
    private Instant lastNotifiedAt;

    /**
     * When the user was last sent an unread *reminder* (§5.4). Written to every
     * one of their participant rows at once, because the daily cap is per user
     * and there is no per-user chat row to hold it.
     */
    @Column(name = "last_reminded_at")
    private Instant lastRemindedAt;
}
