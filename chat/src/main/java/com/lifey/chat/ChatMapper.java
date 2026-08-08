package com.lifey.chat;

import com.lifey.chat.dto.ChatPeerResponse;
import com.lifey.chat.dto.ChatPeerRole;
import com.lifey.chat.dto.ConversationResponse;
import com.lifey.chat.dto.MessageAttachmentResponse;
import com.lifey.chat.dto.MessageResponse;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.spi.ChatUser;

/**
 * Conversations map per-viewer, not once: the same row is "my client" to one
 * side and "my trainer" to the other, and the unread count is the viewer's own.
 */
public final class ChatMapper {

    private ChatMapper() {
    }

    public static MessageResponse toMessageResponse(ChatMessage message) {
        return new MessageResponse(
                message.getId(),
                message.getConversation().getId(),
                message.getSenderId(),
                message.getBody(),
                message.getClientMessageId(),
                message.getCreatedAt(),
                message.getDeletedAt(),
                toAttachment(message));
    }

    /** Metadata only — the bytes are a separate, cacheable request (§18.2). */
    private static MessageAttachmentResponse toAttachment(ChatMessage message) {
        if (!message.hasAttachment()) {
            return null;
        }
        return new MessageAttachmentResponse(
                message.getAttachmentWidth(),
                message.getAttachmentHeight(),
                message.getAttachmentByteSize());
    }

    /**
     * @param peer              the other side of the thread, already resolved
     *                          through {@code ChatUserDirectory} — the
     *                          conversation itself only holds their id
     * @param peerParticipant   the <em>other</em> side's participant row, source
     *                          of the delivered/read cursors the viewer's own
     *                          tick marks are drawn from
     * @param viewerParticipant the viewer's own row, source of {@code mutedUntil}
     *                          <p>
     *                          Both participant rows are nullable so a caller
     *                          that has not loaded them degrades to "sent" ticks
     *                          and "not muted" rather than failing.
     */
    public static ConversationResponse toConversationResponse(ChatConversation conversation,
                                                              Long viewerId,
                                                              ChatUser peer,
                                                              ChatMessage lastMessage,
                                                              long unreadCount,
                                                              ChatParticipant peerParticipant,
                                                              ChatParticipant viewerParticipant) {
        return new ConversationResponse(
                conversation.getId(),
                toPeer(conversation, viewerId, peer),
                lastMessage == null ? null : toMessageResponse(lastMessage),
                unreadCount,
                conversation.getArchivedAt(),
                peerParticipant == null ? null : peerParticipant.getLastDeliveredMessageId(),
                peerParticipant == null ? null : peerParticipant.getLastReadMessageId(),
                viewerParticipant == null ? null : viewerParticipant.getMutedUntil());
    }

    private static ChatPeerResponse toPeer(ChatConversation conversation, Long viewerId, ChatUser peer) {
        ChatPeerRole role = conversation.getTrainerId().equals(viewerId)
                ? ChatPeerRole.CLIENT
                : ChatPeerRole.TRAINER;
        return new ChatPeerResponse(peer.id(), peer.displayName(), peer.email(), role);
    }
}
