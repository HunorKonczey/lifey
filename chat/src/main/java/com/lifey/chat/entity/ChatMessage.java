package com.lifey.chat.entity;

import com.lifey.common.domain.BaseEntity;
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

    /**
     * A plain id, not a {@code User} relation: {@code users} belongs to another
     * module (docs/chat/44-chat-service-extraction-plan.md §2.4). The database
     * still enforces the foreign key.
     */
    @Column(name = "sender_id", nullable = false)
    private Long senderId;

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

    /**
     * Image metadata, all three set together or all three null. Kept here
     * rather than joined from {@link ChatMessageAttachment} because a client
     * needs the aspect ratio to reserve space <em>before</em> the picture
     * arrives — a thread that reflows as images load is unusable.
     */
    @Column(name = "attachment_width")
    private Integer attachmentWidth;

    @Column(name = "attachment_height")
    private Integer attachmentHeight;

    @Column(name = "attachment_byte_size")
    private Integer attachmentByteSize;

    public boolean hasAttachment() {
        return attachmentWidth != null;
    }

    /** Clears the metadata; the bytes are removed by the caller (§18.4/2). */
    public void clearAttachment() {
        attachmentWidth = null;
        attachmentHeight = null;
        attachmentByteSize = null;
    }
}
