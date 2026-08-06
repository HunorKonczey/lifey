package com.lifey.chat;

import com.lifey.chat.dto.ChatPeerResponse;
import com.lifey.chat.dto.ChatPeerRole;
import com.lifey.chat.dto.ConversationResponse;
import com.lifey.chat.dto.MessageResponse;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.user.User;

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
                message.getSender().getId(),
                message.getBody(),
                message.getClientMessageId(),
                message.getCreatedAt(),
                message.getDeletedAt());
    }

    /**
     * @param peerParticipant   the <em>other</em> side's participant row, source
     *                          of the delivered/read cursors the viewer's own
     *                          tick marks are drawn from
     * @param viewerParticipant the viewer's own row, source of {@code mutedUntil}
     *                          <p>
     *                          Both are nullable so a caller that has not loaded
     *                          them degrades to "sent" ticks and "not muted"
     *                          rather than failing.
     */
    public static ConversationResponse toConversationResponse(ChatConversation conversation,
                                                              Long viewerId,
                                                              ChatMessage lastMessage,
                                                              long unreadCount,
                                                              ChatParticipant peerParticipant,
                                                              ChatParticipant viewerParticipant) {
        return new ConversationResponse(
                conversation.getId(),
                toPeer(conversation, viewerId),
                lastMessage == null ? null : toMessageResponse(lastMessage),
                unreadCount,
                conversation.getArchivedAt(),
                peerParticipant == null ? null : peerParticipant.getLastDeliveredMessageId(),
                peerParticipant == null ? null : peerParticipant.getLastReadMessageId(),
                viewerParticipant == null ? null : viewerParticipant.getMutedUntil());
    }

    /** The id of the participant on the other side of the thread from the viewer. */
    public static Long peerIdOf(ChatConversation conversation, Long viewerId) {
        return conversation.getTrainer().getId().equals(viewerId)
                ? conversation.getClient().getId()
                : conversation.getTrainer().getId();
    }

    private static ChatPeerResponse toPeer(ChatConversation conversation, Long viewerId) {
        boolean viewerIsTrainer = conversation.getTrainer().getId().equals(viewerId);
        User peer = viewerIsTrainer ? conversation.getClient() : conversation.getTrainer();
        ChatPeerRole role = viewerIsTrainer ? ChatPeerRole.CLIENT : ChatPeerRole.TRAINER;
        return new ChatPeerResponse(peer.getId(), displayName(peer), peer.getEmail(), role);
    }

    /**
     * Name if we have one, email otherwise — a user who signed up without
     * filling in their profile still needs something to show in a thread header.
     * Public because the push copy (see {@code ChatNotificationServiceImpl})
     * titles a notification with exactly the name the thread header shows.
     */
    public static String displayName(User user) {
        String name = ((user.getFirstName() == null ? "" : user.getFirstName()) + " "
                + (user.getLastName() == null ? "" : user.getLastName())).trim();
        return name.isEmpty() ? user.getEmail() : name;
    }
}
