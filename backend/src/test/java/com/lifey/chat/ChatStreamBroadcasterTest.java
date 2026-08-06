package com.lifey.chat;

import com.lifey.chat.dto.ChatEvent;
import com.lifey.chat.dto.MessageEventPayload;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.repository.ChatMessageRepository;
import com.lifey.chat.service.ChatEventBus;
import com.lifey.chat.service.ChatPresenceRegistry;
import com.lifey.chat.service.ChatReceiptService;
import com.lifey.user.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * What an open screen sees when a message lands, and which of the two cursors
 * moves as a result (§4.4, §5.1).
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ChatStreamBroadcasterTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;
    private static final Long CONVERSATION_ID = 10L;
    private static final Long MESSAGE_ID = 100L;

    @Mock
    ChatMessageRepository messageRepository;

    @Mock
    ChatEventBus eventBus;

    @Mock
    ChatPresenceRegistry presenceRegistry;

    @Mock
    ChatReceiptService receiptService;

    @InjectMocks
    ChatStreamBroadcaster broadcaster;

    ChatConversation conversation;
    User trainer;
    User client;

    @BeforeEach
    void setUp() {
        trainer = user(TRAINER_ID);
        client = user(CLIENT_ID);
        conversation = new ChatConversation();
        conversation.setId(CONVERSATION_ID);
        conversation.setTrainer(trainer);
        conversation.setClient(client);
        storedMessage(trainer);
    }

    @Test
    void bothSidesGetTheMessageFrame() {
        broadcaster.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        // The sender's own other clients need it too — a second tab or the
        // phone that did not send it should show the bubble without a refresh.
        assertThat(captureFrame(TRAINER_ID).name()).isEqualTo(ChatEvent.MESSAGE);
        ChatEvent recipientFrame = captureFrame(CLIENT_ID);
        assertThat(recipientFrame.id()).isEqualTo(MESSAGE_ID);
        assertThat(((MessageEventPayload) recipientFrame.data()).conversationId()).isEqualTo(CONVERSATION_ID);
    }

    @Test
    void aRecipientWithALiveStreamCountsAsDelivered() {
        when(eventBus.publish(eq(CLIENT_ID), any())).thenReturn(true);
        when(presenceRegistry.isViewing(CLIENT_ID, CONVERSATION_ID)).thenReturn(false);

        broadcaster.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(receiptService).recordDelivered(CONVERSATION_ID, CLIENT_ID, MESSAGE_ID);
        verify(receiptService, never()).recordSeen(anyLong(), anyLong(), anyLong());
    }

    @Test
    void aRecipientLookingAtTheThreadCountsAsRead() {
        when(eventBus.publish(eq(CLIENT_ID), any())).thenReturn(true);
        when(presenceRegistry.isViewing(CLIENT_ID, CONVERSATION_ID)).thenReturn(true);

        broadcaster.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(receiptService).recordSeen(CONVERSATION_ID, CLIENT_ID, MESSAGE_ID);
        verify(receiptService, never()).recordDelivered(anyLong(), anyLong(), anyLong());
    }

    @Test
    void anOfflineRecipientAdvancesNeitherCursor() {
        when(eventBus.publish(eq(CLIENT_ID), any())).thenReturn(false);
        // Presence without a connection is stale and must not imply delivery.
        when(presenceRegistry.isViewing(CLIENT_ID, CONVERSATION_ID)).thenReturn(true);

        broadcaster.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(receiptService, never()).recordDelivered(anyLong(), anyLong(), anyLong());
        verify(receiptService, never()).recordSeen(anyLong(), anyLong(), anyLong());
    }

    @Test
    void aReadCursorEventBroadcastsTheCursors() {
        broadcaster.onReadCursorAdvanced(new ChatReadCursorEvent(CONVERSATION_ID, CLIENT_ID));

        verify(receiptService).broadcastCursors(CONVERSATION_ID, CLIENT_ID);
    }

    @Test
    void aFailureIsSwallowed_soASendNeverFailsBecauseOfTheStream() {
        when(messageRepository.findById(MESSAGE_ID)).thenThrow(new IllegalStateException("db down"));

        assertThatCode(() -> broadcaster.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID)))
                .doesNotThrowAnyException();
    }

    @Test
    void aMissingMessageIsIgnored() {
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.empty());

        broadcaster.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(eventBus, never()).publish(anyLong(), any());
    }

    private ChatEvent captureFrame(Long userId) {
        ArgumentCaptor<ChatEvent> captor = ArgumentCaptor.captor();
        verify(eventBus).publish(eq(userId), captor.capture());
        return captor.getValue();
    }

    private void storedMessage(User sender) {
        ChatMessage message = new ChatMessage();
        message.setId(MESSAGE_ID);
        message.setConversation(conversation);
        message.setSender(sender);
        message.setBody("Holnap 17:00 jó?");
        message.setClientMessageId("uuid-1");
        message.setCreatedAt(Instant.parse("2026-08-06T09:00:00Z"));
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.of(message));
    }

    private static User user(Long id) {
        User user = new User();
        user.setId(id);
        user.setEmail("user" + id + "@example.com");
        return user;
    }
}
