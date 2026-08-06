package com.lifey.chat;

import com.lifey.chat.dto.ChatPeerResponse;
import com.lifey.chat.dto.ChatPeerRole;
import com.lifey.chat.dto.ConversationResponse;
import com.lifey.chat.dto.MessageResponse;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
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

    public static ConversationResponse toConversationResponse(ChatConversation conversation,
                                                              Long viewerId,
                                                              ChatMessage lastMessage,
                                                              long unreadCount) {
        return new ConversationResponse(
                conversation.getId(),
                toPeer(conversation, viewerId),
                lastMessage == null ? null : toMessageResponse(lastMessage),
                unreadCount,
                conversation.getArchivedAt());
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
