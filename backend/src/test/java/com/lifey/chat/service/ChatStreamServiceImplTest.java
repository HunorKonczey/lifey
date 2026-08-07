package com.lifey.chat.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.chat.ChatProperties;
import com.lifey.chat.dto.ChatEvent;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.repository.ChatConversationRepository;
import com.lifey.chat.repository.ChatMessageRepository;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.Pageable;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * The reconnect contract (§4.4): a client that says where it got to is caught
 * up frame by frame, a client too far behind is told to reload, and a fresh
 * client is left to the REST API.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ChatStreamServiceImplTest {

    private static final Long USER_ID = 7L;
    private static final Long CONVERSATION_ID = 12L;
    private static final int CATCH_UP_LIMIT = 3;

    @Mock
    ChatMessageRepository messageRepository;

    @Mock
    ChatConversationRepository conversationRepository;

    @Mock
    ChatEmitterRegistry registry;

    @Mock
    ChatEventBus eventBus;

    @Mock
    ChatPresenceRegistry presenceRegistry;

    @Mock
    ChatReceiptService receiptService;

    @Mock
    CurrentUserProvider currentUserProvider;

    ChatStreamServiceImpl streamService;
    ChatTypingThrottle throttle;

    private static ChatProperties properties() {
        return new ChatProperties(true, 2000, 30, 100, 30, 600,
                Duration.ofMinutes(5), CATCH_UP_LIMIT, Duration.ofMinutes(2),
                Duration.ofSeconds(60), Duration.ofMinutes(30), 1, false,
                Duration.ofHours(24), 8L * 1024 * 1024, 1600, 400,
                // Zero: the throttle has its own test, and a real interval here
                // would make every typing case in this class order-dependent.
                Duration.ZERO, Duration.ofSeconds(5), 2);
    }

    @BeforeEach
    void setUp() {
        when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        throttle = new ChatTypingThrottle(properties());
        streamService = new ChatStreamServiceImpl(messageRepository, conversationRepository, registry,
                eventBus, presenceRegistry, receiptService, throttle, currentUserProvider,
                properties());
    }

    @Test
    void openingAStreamRegistersItAndMarksEverythingDelivered() {
        SseEmitter emitter = streamService.open(null);

        assertThat(emitter.getTimeout()).isEqualTo(Duration.ofMinutes(5).toMillis());
        verify(registry).register(eq(USER_ID), eq(emitter), any());
        verify(receiptService).markDeliveredOnConnect(USER_ID);
    }

    @Test
    void openingAStreamWritesImmediately_soTheClientIsNotBlindUntilTheFirstHeartbeat() {
        // Without a first byte the container never commits the response, and
        // the client's connect hangs until the heartbeat — measured at ~20s.
        SseEmitter emitter = streamService.open(null);

        verify(registry).sendOpeningComment(USER_ID, emitter);
    }

    @Test
    void aFreshClientGetsNoReplay() {
        streamService.open(null);

        verify(messageRepository, never()).findAllForParticipantAfter(anyLong(), anyLong(), any());
        verify(registry, never()).sendTo(anyLong(), any(), any());
    }

    @Test
    void aReconnectReplaysWhatWasMissed_inOrder() {
        when(messageRepository.findAllForParticipantAfter(eq(USER_ID), eq(100L), any(Pageable.class)))
                .thenReturn(List.of(message(101L), message(102L)));

        SseEmitter emitter = streamService.open(100L);

        ArgumentCaptor<ChatEvent> frames = ArgumentCaptor.captor();
        verify(registry, org.mockito.Mockito.times(2)).sendTo(eq(USER_ID), eq(emitter), frames.capture());
        assertThat(frames.getAllValues()).extracting(ChatEvent::name).containsOnly(ChatEvent.MESSAGE);
        assertThat(frames.getAllValues()).extracting(ChatEvent::id).containsExactly(101L, 102L);
    }

    @Test
    void aClientTooFarBehindIsToldToResyncInsteadOfBeingFloodedWithFrames() {
        // One over the limit is what the extra probe row is there to detect.
        when(messageRepository.findAllForParticipantAfter(eq(USER_ID), eq(1L), any(Pageable.class)))
                .thenReturn(IntStream.rangeClosed(2, 2 + CATCH_UP_LIMIT)
                        .mapToObj(id -> message((long) id))
                        .toList());

        SseEmitter emitter = streamService.open(1L);

        ArgumentCaptor<ChatEvent> frame = ArgumentCaptor.captor();
        verify(registry).sendTo(eq(USER_ID), eq(emitter), frame.capture());
        assertThat(frame.getValue().name()).isEqualTo(ChatEvent.RESYNC);
        assertThat(frame.getValue().id()).isNull();
    }

    @Test
    void presenceIsForwardedToTheRegistry() {
        streamService.updatePresence(CONVERSATION_ID);
        verify(presenceRegistry).set(USER_ID, CONVERSATION_ID);

        streamService.updatePresence(null);
        verify(presenceRegistry).set(USER_ID, null);
    }

    private static ChatMessage message(Long id) {
        User sender = new User();
        sender.setId(99L);

        ChatConversation conversation = new ChatConversation();
        conversation.setId(CONVERSATION_ID);

        ChatMessage message = new ChatMessage();
        message.setId(id);
        message.setConversation(conversation);
        message.setSender(sender);
        message.setBody("hello");
        message.setClientMessageId("uuid-" + id);
        message.setCreatedAt(Instant.parse("2026-08-06T09:00:00Z"));
        return message;
    }

    // --- typing (I6) --------------------------------------------------------

    @Test
    void typingReachesThePeerOnly_notTheSendersOwnOtherDevices() {
        ChatConversation conversation = conversation(USER_ID, 88L);
        when(conversationRepository.findByIdForParticipant(CONVERSATION_ID, USER_ID))
                .thenReturn(Optional.of(conversation));

        streamService.typing(CONVERSATION_ID);

        ArgumentCaptor<ChatEvent> captor = ArgumentCaptor.captor();
        verify(eventBus).publish(eq(88L), captor.capture());
        assertThat(captor.getValue().name()).isEqualTo(ChatEvent.TYPING);
        // No id: a typing hint is not a message and must never move a cursor
        // that means "the newest message I have".
        assertThat(captor.getValue().id()).isNull();
        verify(eventBus, never()).publish(eq(USER_ID), any());
    }

    @Test
    void typingInAnArchivedThreadIsDropped() {
        ChatConversation conversation = conversation(USER_ID, 88L);
        conversation.setArchivedAt(Instant.parse("2026-08-01T08:00:00Z"));
        when(conversationRepository.findByIdForParticipant(CONVERSATION_ID, USER_ID))
                .thenReturn(Optional.of(conversation));

        streamService.typing(CONVERSATION_ID);

        // Nothing can be sent to an archived thread, so nobody is writing in it.
        verify(eventBus, never()).publish(anyLong(), any());
    }

    @Test
    void typingInSomeoneElsesThreadIsNotFound() {
        when(conversationRepository.findByIdForParticipant(CONVERSATION_ID, USER_ID))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> streamService.typing(CONVERSATION_ID))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(eventBus, never()).publish(anyLong(), any());
    }

    private static ChatConversation conversation(Long trainerId, Long clientId) {
        ChatConversation conversation = new ChatConversation();
        conversation.setId(CONVERSATION_ID);
        conversation.setTrainer(user(trainerId));
        conversation.setClient(user(clientId));
        return conversation;
    }

    private static User user(Long id) {
        User user = new User();
        user.setId(id);
        user.setEmail("user" + id + "@example.com");
        return user;
    }

}
