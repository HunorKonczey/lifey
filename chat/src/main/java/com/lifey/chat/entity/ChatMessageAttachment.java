package com.lifey.chat.entity;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * The bytes of one message's image, stored the same way recipe photos are: a
 * re-encoded JPEG plus a square thumbnail, both decoded and re-encoded on the
 * way in, which validates the upload and strips EXIF/GPS in one step
 * (docs/chat/40-trainer-chat-plan.md §18).
 *
 * <p>Its own table on purpose — see {@code V67__chat_attachments.sql}. The
 * message keeps the metadata (dimensions, size); only the pixels live here.
 */
@Getter
@Setter
@Entity
@Table(name = "chat_message_attachments")
public class ChatMessageAttachment extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "message_id", nullable = false, unique = true)
    private ChatMessage message;

    /** Resized so the longest side fits {@code lifey.chat.attachment-max-side}. */
    @Column(name = "image", nullable = false)
    private byte[] image;

    /** Same aspect ratio, smaller — what the bubble shows before a tap opens the full image. */
    @Column(name = "thumbnail", nullable = false)
    private byte[] thumbnail;

    @Column(name = "content_type", nullable = false, length = 64)
    private String contentType;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;
}
