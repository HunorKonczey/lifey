package com.lifey.chat.service;

import com.lifey.chat.dto.ChatEvent;
import com.lifey.chat.dto.ReadEventPayload;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.repository.ChatConversationRepository;
import com.lifey.chat.repository.ChatParticipantRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Transactional
public class ChatReceiptServiceImpl implements ChatReceiptService {

    private final ChatParticipantRepository participantRepository;
    private final ChatConversationRepository conversationRepository;
    private final ChatEventBus eventBus;

    @Override
    public void markDeliveredOnConnect(Long userId) {
        for (ChatParticipant participant : participantRepository.findAllForUser(userId)) {
            Long lastMessageId = participant.getConversation().getLastMessageId();
            if (lastMessageId != null && advanceDelivered(participant, lastMessageId)) {
                // Only threads whose cursor actually moved produce a frame —
                // a trainer with fifty threads should not get fifty no-ops.
                publishCursors(participant.getConversation(), userId, participant);
            }
        }
    }

    @Override
    public void recordDelivered(Long conversationId, Long userId, Long messageId) {
        participant(conversationId, userId).ifPresent(participant -> {
            if (advanceDelivered(participant, messageId)) {
                publishCursors(participant.getConversation(), userId, participant);
            }
        });
    }

    @Override
    public void recordSeen(Long conversationId, Long userId, Long messageId) {
        participant(conversationId, userId).ifPresent(participant -> {
            boolean moved = advanceDelivered(participant, messageId);
            if (participant.getLastReadMessageId() == null || participant.getLastReadMessageId() < messageId) {
                participant.setLastReadMessageId(messageId);
                participant.setLastReadAt(Instant.now());
                moved = true;
            }
            if (moved) {
                publishCursors(participant.getConversation(), userId, participant);
            }
        });
    }

    @Override
    public void broadcastCursors(Long conversationId, Long userId) {
        participant(conversationId, userId)
                .ifPresent(participant -> publishCursors(participant.getConversation(), userId, participant));
    }

    private Optional<ChatParticipant> participant(Long conversationId, Long userId) {
        return participantRepository.findByConversationIdAndUserId(conversationId, userId);
    }

    private static boolean advanceDelivered(ChatParticipant participant, Long messageId) {
        Long current = participant.getLastDeliveredMessageId();
        if (current != null && current >= messageId) {
            return false;
        }
        participant.setLastDeliveredMessageId(messageId);
        return true;
    }

    /**
     * The frame goes to the <em>other</em> participant: cursors are only ever
     * interesting to the person waiting for their own message to land.
     */
    private void publishCursors(ChatConversation conversation, Long userId, ChatParticipant participant) {
        // The conversation may arrive as a lazy proxy (participant.getConversation()
        // from a cursor lookup), and peer resolution has to read its columns.
        ChatConversation loaded = conversationRepository.findById(conversation.getId()).orElse(null);
        if (loaded == null) {
            return;
        }
        Long peerId = loaded.peerOf(userId);
        eventBus.publish(peerId, ChatEvent.read(new ReadEventPayload(
                loaded.getId(),
                userId,
                participant.getLastDeliveredMessageId(),
                participant.getLastReadMessageId())));
    }
}
