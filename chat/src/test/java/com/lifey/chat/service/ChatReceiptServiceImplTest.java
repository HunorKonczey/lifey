package com.lifey.chat.service;

import com.lifey.chat.dto.ChatEvent;
import com.lifey.chat.dto.ReadEventPayload;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.repository.ChatConversationRepository;
import com.lifey.chat.repository.ChatParticipantRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Cursors move forward only, and only a real move is announced — otherwise
 * every scroll and every reconnect would put a frame on the stream.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ChatReceiptServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;
    private static final Long CONVERSATION_ID = 10L;

    @Mock
    ChatParticipantRepository participantRepository;

    @Mock
    ChatConversationRepository conversationRepository;

    @Mock
    ChatEventBus eventBus;

    @InjectMocks
    ChatReceiptServiceImpl receiptService;

    ChatConversation conversation;
    ChatParticipant clientParticipant;

    @BeforeEach
    void setUp() {
        conversation = new ChatConversation();
        conversation.setId(CONVERSATION_ID);
        conversation.setTrainerId(TRAINER_ID);
        conversation.setClientId(CLIENT_ID);

        clientParticipant = new ChatParticipant();
        clientParticipant.setConversation(conversation);
        clientParticipant.setUserId(CLIENT_ID);

        when(conversationRepository.findById(CONVERSATION_ID)).thenReturn(Optional.of(conversation));
        when(participantRepository.findByConversationIdAndUserId(CONVERSATION_ID, CLIENT_ID))
                .thenReturn(Optional.of(clientParticipant));
    }

    @Test
    void deliveryAdvancesTheCursorAndTellsTheOtherSide() {
        receiptService.recordDelivered(CONVERSATION_ID, CLIENT_ID, 100L);

        assertThat(clientParticipant.getLastDeliveredMessageId()).isEqualTo(100L);
        ReadEventPayload payload = capturePayloadSentTo(TRAINER_ID);
        assertThat(payload.userId()).isEqualTo(CLIENT_ID);
        assertThat(payload.lastDeliveredMessageId()).isEqualTo(100L);
        assertThat(payload.lastReadMessageId()).isNull();
    }

    @Test
    void aStaleDeliveryIsIgnoredAndAnnouncesNothing() {
        clientParticipant.setLastDeliveredMessageId(200L);

        receiptService.recordDelivered(CONVERSATION_ID, CLIENT_ID, 100L);

        assertThat(clientParticipant.getLastDeliveredMessageId()).isEqualTo(200L);
        verify(eventBus, never()).publish(anyLong(), any());
    }

    @Test
    void seenAdvancesBothCursors_becauseReadImpliesDelivered() {
        receiptService.recordSeen(CONVERSATION_ID, CLIENT_ID, 100L);

        assertThat(clientParticipant.getLastDeliveredMessageId()).isEqualTo(100L);
        assertThat(clientParticipant.getLastReadMessageId()).isEqualTo(100L);
        assertThat(clientParticipant.getLastReadAt()).isNotNull();
        assertThat(capturePayloadSentTo(TRAINER_ID).lastReadMessageId()).isEqualTo(100L);
    }

    @Test
    void connectingMarksEveryThreadDeliveredUpToItsLastMessage() {
        conversation.setLastMessageId(310L);
        when(participantRepository.findAllForUser(CLIENT_ID)).thenReturn(List.of(clientParticipant));

        receiptService.markDeliveredOnConnect(CLIENT_ID);

        assertThat(clientParticipant.getLastDeliveredMessageId()).isEqualTo(310L);
        assertThat(capturePayloadSentTo(TRAINER_ID).lastDeliveredMessageId()).isEqualTo(310L);
    }

    @Test
    void connectingIsSilentForThreadsThatWereAlreadyCaughtUp() {
        conversation.setLastMessageId(310L);
        clientParticipant.setLastDeliveredMessageId(310L);
        when(participantRepository.findAllForUser(CLIENT_ID)).thenReturn(List.of(clientParticipant));

        receiptService.markDeliveredOnConnect(CLIENT_ID);

        verify(eventBus, never()).publish(anyLong(), any());
    }

    @Test
    void anEmptyThreadHasNothingToDeliver() {
        conversation.setLastMessageId(null);
        when(participantRepository.findAllForUser(CLIENT_ID)).thenReturn(List.of(clientParticipant));

        receiptService.markDeliveredOnConnect(CLIENT_ID);

        assertThat(clientParticipant.getLastDeliveredMessageId()).isNull();
        verify(eventBus, never()).publish(anyLong(), any());
    }

    private ReadEventPayload capturePayloadSentTo(Long userId) {
        ArgumentCaptor<ChatEvent> captor = ArgumentCaptor.captor();
        verify(eventBus).publish(eq(userId), captor.capture());
        assertThat(captor.getValue().name()).isEqualTo(ChatEvent.READ);
        // No id on a read frame: only message frames move Last-Event-ID.
        assertThat(captor.getValue().id()).isNull();
        return (ReadEventPayload) captor.getValue().data();
    }
}
