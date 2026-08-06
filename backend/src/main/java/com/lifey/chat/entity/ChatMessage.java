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
 * One plain-text message. Immutable once written, apart from the tombstone:
 * deleting clears {@link #body} and stamps {@link #deletedAt}, leaving the row
 * in place so the other side keeps the context of their replies
 * (docs/chat/40-trainer-chat-plan.md §1.3/2).
 */
@Getter
@Setter
@Entity
@Table(name = "chat_messages")
public class ChatMessage extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "conversation_id", nullable = false)
    private ChatConversation conversation;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "sender_id", nullable = false)
    private User sender;

    /** Null once tombstoned; never logged (§7.4). */
    @Column(name = "body")
    private String body;

    /**
     * Client-generated id, unique per conversation. Re-sending the same value
     * returns the stored message instead of creating a second one, which is
     * what makes the mobile outbox's blind retry safe (§4.2).
     */
    @Column(name = "client_message_id", nullable = false, length = 64)
    private String clientMessageId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;
}
