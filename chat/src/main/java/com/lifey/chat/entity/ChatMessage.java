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
 * One message: plain text, an image or a result card. Immutable once written, apart from the tombstone:
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

    /**
     * The shared result card, as the validated JSON text of a
     * {@code MessageCard}, and its kind beside it for the database to check.
     * Both set or both null (docs/chat/83-chat-result-card-plan.md §2.4). Never
     * read as data by anything but the clients' renderers — it is what the
     * sender said, not a record (§2.3).
     */
    @Column(name = "card_kind", length = 16)
    private String cardKind;

    @Column(name = "card_data")
    private String cardData;

    public boolean hasAttachment() {
        return attachmentWidth != null;
    }

    public boolean hasCard() {
        return cardKind != null;
    }

    /** Clears the card; part of the tombstone, so the details really go (§8 risk 3). */
    public void clearCard() {
        cardKind = null;
        cardData = null;
    }

    /** Clears the metadata; the bytes are removed by the caller (§18.4/2). */
    public void clearAttachment() {
        attachmentWidth = null;
        attachmentHeight = null;
        attachmentByteSize = null;
    }
}
