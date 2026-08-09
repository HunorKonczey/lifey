package com.lifey.chat.service;

import com.lifey.chat.ChatMapper;
import com.lifey.chat.ChatProperties;
import com.lifey.chat.dto.ChatEvent;
import com.lifey.chat.dto.MessageDeletedEventPayload;
import com.lifey.chat.dto.MessageEventPayload;
import com.lifey.chat.dto.TypingEventPayload;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.repository.ChatConversationRepository;
import com.lifey.chat.repository.ChatMessageRepository;
import com.lifey.chat.spi.ChatCaller;
import com.lifey.common.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.time.Instant;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class ChatStreamServiceImpl implements ChatStreamService {

    private final ChatMessageRepository messageRepository;
    private final ChatConversationRepository conversationRepository;
    private final ChatEmitterRegistry registry;
    private final ChatEventBus eventBus;
    private final ChatPresenceRegistry presenceRegistry;
    private final ChatReceiptService receiptService;
    private final ChatTypingThrottle throttle;
    private final ChatCaller caller;
    private final ChatProperties properties;

    @Override
    @Transactional
    public SseEmitter open(Long lastEventId) {
        Long userId = caller.currentUserId();
        SseEmitter emitter = new SseEmitter(properties.streamTimeout().toMillis());

        // Registered before the replay, not after. A message arriving in
        // between then reaches the client twice — harmless, since clients merge
        // on message id — whereas registering afterwards would drop it, and a
        // lost message is the one failure this design does not accept.
        registry.register(userId, emitter, () -> {
            if (!registry.isConnected(userId)) {
                // Last connection gone: whatever thread they were viewing, they
                // are not viewing it now, so pushes must resume immediately.
                presenceRegistry.clear(userId);
            }
        });

        // First byte, immediately: it commits the response, so the client knows
        // it is connected now rather than at the next heartbeat.
        registry.sendOpeningComment(userId, emitter);

        replayMissed(userId, lastEventId, emitter);
        receiptService.markDeliveredOnConnect(userId);
        return emitter;
    }

    @Override
    public void updatePresence(Long activeConversationId) {
        presenceRegistry.set(caller.currentUserId(), activeConversationId);
    }

    @Override
    @Transactional(readOnly = true)
    public void typing(Long conversationId) {
        Long userId = caller.currentUserId();
        // Same guard as everywhere else: someone outside the thread gets a 404,
        // not a 403, and certainly not the ability to poke the participants.
        ChatConversation conversation = conversationRepository.findByIdForParticipant(conversationId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found: " + conversationId));
        // An archived thread cannot be written to, so nobody is typing in it.
        if (conversation.getArchivedAt() != null || !throttle.allow(conversationId, userId)) {
            return;
        }
        // The peer only. Echoing "you are typing" to the sender's own second
        // device would be noise about something they are doing themselves.
        eventBus.publish(conversation.peerOf(userId),
                ChatEvent.typing(new TypingEventPayload(conversationId, userId)));
    }

    /**
     * Bridge the gap the client missed while its stream was down. A client
     * without a cursor is not a gap — it is a fresh client, and it loads the
     * thread over REST anyway, so replaying anything to it would be waste.
     */
    private void replayMissed(Long userId, Long lastEventId, SseEmitter emitter) {
        if (lastEventId == null) {
            return;
        }
        int limit = properties.streamCatchUpLimit();
        List<ChatMessage> missed = messageRepository.findAllForParticipantAfter(
                userId, lastEventId, PageRequest.of(0, limit + 1));

        if (missed.size() > limit) {
            // Too far behind to replay honestly — say so and let the client
            // reload. The stream is a fast path over REST, never the truth.
            registry.sendTo(userId, emitter, ChatEvent.resync());
            return;
        }
        for (ChatMessage message : missed) {
            registry.sendTo(userId, emitter, ChatEvent.message(new MessageEventPayload(
                    message.getConversation().getId(), ChatMapper.toMessageResponse(message))));
        }
        replayTombstones(userId, lastEventId, emitter);
    }

    /**
     * The other half of catching up: what was <em>deleted</em> below the
     * client's cursor while it was away.
     *
     * <p>Without this a tombstone exists only as a live frame — miss it, and
     * the peer goes on showing text the server has already destroyed, for as
     * long as their cache lives (§17.5 named this limit; this is where the plan
     * said the fix belongs). Replaying is safe to do on every connect because
     * applying a tombstone is idempotent on both clients, and it is bounded by
     * {@code stream-tombstone-window} so it stays a small, recent sweep rather
     * than the whole history of the thread.
     */
    private void replayTombstones(Long userId, Long lastEventId, SseEmitter emitter) {
        Instant since = Instant.now().minus(properties.streamTombstoneWindow());
        List<ChatMessage> deleted = messageRepository.findTombstonesForParticipantUpTo(
                userId, lastEventId, since, PageRequest.of(0, properties.streamCatchUpLimit()));

        for (ChatMessage message : deleted) {
            registry.sendTo(userId, emitter, ChatEvent.deleted(new MessageDeletedEventPayload(
                    message.getConversation().getId(), message.getId(), message.getDeletedAt())));
        }
    }
}
