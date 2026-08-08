package com.lifey.chat;

import com.lifey.chat.dto.ChatEvent;
import com.lifey.chat.dto.MessageDeletedEventPayload;
import com.lifey.chat.dto.MessageEventPayload;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.repository.ChatMessageRepository;
import com.lifey.chat.service.ChatEventBus;
import com.lifey.chat.service.ChatPresenceRegistry;
import com.lifey.chat.service.ChatReceiptService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Turns committed chat writes into stream frames (§4.4).
 *
 * <p>Split from {@code ChatNotificationServiceImpl} on purpose: that class
 * decides whether to <em>interrupt</em> someone, this one decides what their
 * already-open screens should show. They read the same presence signal and
 * write nothing in common, so their order does not matter.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ChatStreamBroadcaster {

    private final ChatMessageRepository messageRepository;
    private final ChatEventBus eventBus;
    private final ChatPresenceRegistry presenceRegistry;
    private final ChatReceiptService receiptService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onMessageStored(ChatMessageStoredEvent event) {
        try {
            broadcast(event.messageId());
        } catch (RuntimeException ex) {
            // The message is committed and the REST API already serves it; a
            // stream problem must not surface to the sender. Ids only, never
            // the body (§7.4).
            log.error("Chat stream broadcast failed for message {}", event.messageId(), ex);
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onMessageDeleted(ChatMessageDeletedEvent event) {
        try {
            broadcastDeletion(event.messageId());
        } catch (RuntimeException ex) {
            log.error("Chat stream deletion broadcast failed for message {}", event.messageId(), ex);
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onReadCursorAdvanced(ChatReadCursorEvent event) {
        try {
            receiptService.broadcastCursors(event.conversationId(), event.userId());
        } catch (RuntimeException ex) {
            log.error("Chat read receipt broadcast failed for conversation {}", event.conversationId(), ex);
        }
    }

    private void broadcast(Long messageId) {
        ChatMessage message = messageRepository.findById(messageId).orElse(null);
        if (message == null) {
            return;
        }
        ChatConversation conversation = message.getConversation();
        Long senderId = message.getSenderId();
        Long recipientId = conversation.peerOf(senderId);

        ChatEvent frame = ChatEvent.message(new MessageEventPayload(
                conversation.getId(), ChatMapper.toMessageResponse(message)));

        // The sender's own other clients get it too: a second tab or the phone
        // that did not send it should show the bubble without a refresh.
        eventBus.publish(senderId, frame);
        boolean delivered = eventBus.publish(recipientId, frame);

        if (delivered && presenceRegistry.isViewing(recipientId, conversation.getId())) {
            // §5.1: they are looking at this thread, so it is read on arrival —
            // and ChatNotificationService skips the push for the same reason.
            receiptService.recordSeen(conversation.getId(), recipientId, messageId);
        } else if (delivered) {
            receiptService.recordDelivered(conversation.getId(), recipientId, messageId);
        }
    }

    /**
     * Both sides, and no receipt bookkeeping: a tombstone is not a new message,
     * so it must not move anyone's delivered or read cursor. The sender's own
     * other devices are included for the same reason as on a send — a phone
     * that did not perform the deletion should still stop showing the text.
     */
    private void broadcastDeletion(Long messageId) {
        ChatMessage message = messageRepository.findById(messageId).orElse(null);
        if (message == null || message.getDeletedAt() == null) {
            return;
        }
        ChatConversation conversation = message.getConversation();
        ChatEvent frame = ChatEvent.deleted(new MessageDeletedEventPayload(
                conversation.getId(), message.getId(), message.getDeletedAt()));

        eventBus.publish(conversation.getTrainerId(), frame);
        eventBus.publish(conversation.getClientId(), frame);
    }
}
