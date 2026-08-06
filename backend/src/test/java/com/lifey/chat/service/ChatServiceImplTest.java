package com.lifey.chat.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.chat.ChatMessageStoredEvent;
import com.lifey.chat.ChatProperties;
import com.lifey.chat.dto.ChatPeerRole;
import com.lifey.chat.dto.ConversationResponse;
import com.lifey.chat.dto.MessageListResponse;
import com.lifey.chat.dto.SendMessageRequest;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.exception.ChatDisabledException;
import com.lifey.chat.exception.ConversationArchivedException;
import com.lifey.chat.exception.InvalidMessageBodyException;
import com.lifey.chat.repository.ChatConversationRepository;
import com.lifey.chat.repository.ChatMessageRepository;
import com.lifey.chat.repository.ChatParticipantRepository;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.user.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Pageable;

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
 * Covers the rules that make the chat API safe to call from an offline-first
 * client: idempotent sends, a read cursor that only ever moves forward, and a
 * participant guard that answers 404 rather than 403
 * (docs/chat/40-trainer-chat-plan.md, iteration I1 "Tesztek").
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ChatServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;
    private static final Long CONVERSATION_ID = 10L;
    private static final Long RELATIONSHIP_ID = 55L;

    @Mock
    ChatConversationRepository conversationRepository;

    @Mock
    ChatMessageRepository messageRepository;

    @Mock
    ChatParticipantRepository participantRepository;

    @Mock
    TrainerClientRepository trainerClientRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @Mock
    ChatRateLimiter rateLimiter;

    @Mock
    ApplicationEventPublisher eventPublisher;

    ChatProperties properties = new ChatProperties(true, 2000, 30, 100, 30, 600,
            Duration.ofMinutes(5), 200, Duration.ofMinutes(2),
            Duration.ofSeconds(60), Duration.ofMinutes(30), 1, false, Duration.ofHours(24));

    ChatServiceImpl chatService;

    User trainer;
    User client;
    ChatConversation conversation;
    ChatParticipant trainerParticipant;

    @BeforeEach
    void setUp() {
        trainer = user(TRAINER_ID, "Trainer", "One");
        client = user(CLIENT_ID, "Client", "Two");

        conversation = new ChatConversation();
        conversation.setId(CONVERSATION_ID);
        conversation.setTrainer(trainer);
        conversation.setClient(client);
        conversation.setCreatedAt(Instant.parse("2026-08-01T08:00:00Z"));

        trainerParticipant = new ChatParticipant();
        trainerParticipant.setConversation(conversation);
        trainerParticipant.setUser(trainer);

        chatService = new ChatServiceImpl(conversationRepository, messageRepository, participantRepository,
                trainerClientRepository, currentUserProvider, rateLimiter, properties, eventPublisher);

        when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
        when(conversationRepository.findByIdForParticipant(CONVERSATION_ID, TRAINER_ID))
                .thenReturn(Optional.of(conversation));
        when(participantRepository.findByConversationIdAndUserId(CONVERSATION_ID, TRAINER_ID))
                .thenReturn(Optional.of(trainerParticipant));
        // Mimic IDENTITY generation so the caller can read the id back.
        when(messageRepository.save(any(ChatMessage.class))).thenAnswer(invocation -> {
            ChatMessage saved = invocation.getArgument(0);
            if (saved.getId() == null) {
                saved.setId(100L);
            }
            return saved;
        });
    }

    // --- sending -----------------------------------------------------------

    @Test
    void sendMessage_storesMessageAndUpdatesConversationPointers() {
        var result = chatService.sendMessage(CONVERSATION_ID, new SendMessageRequest("  Holnap 17:00 jó?  ", "uuid-1"));

        assertThat(result.created()).isTrue();
        assertThat(result.message().body()).isEqualTo("Holnap 17:00 jó?");
        assertThat(result.message().senderId()).isEqualTo(TRAINER_ID);
        assertThat(conversation.getLastMessageId()).isEqualTo(100L);
        assertThat(conversation.getLastMessageAt()).isNotNull();
    }

    @Test
    void sendMessage_marksTheSendersOwnMessageAsRead() {
        chatService.sendMessage(CONVERSATION_ID, new SendMessageRequest("Persze!", "uuid-1"));

        assertThat(trainerParticipant.getLastReadMessageId()).isEqualTo(100L);
        assertThat(trainerParticipant.getLastReadAt()).isNotNull();
    }

    @Test
    void sendMessage_replayingTheSameClientMessageId_returnsStoredMessageWithoutWriting() {
        ChatMessage stored = message(42L, trainer, "Persze!", "uuid-1");
        when(messageRepository.findByConversationIdAndClientMessageId(CONVERSATION_ID, "uuid-1"))
                .thenReturn(Optional.of(stored));

        var result = chatService.sendMessage(CONVERSATION_ID, new SendMessageRequest("Persze!", "uuid-1"));

        assertThat(result.created()).isFalse();
        assertThat(result.message().id()).isEqualTo(42L);
        verify(messageRepository, never()).save(any());
        // A retry is not new traffic — it must not consume rate-limit budget.
        verify(rateLimiter, never()).requireSendAllowance(anyLong());
        // ...and must not push the recipient a second time for one message.
        verify(eventPublisher, never()).publishEvent(any(ChatMessageStoredEvent.class));
    }

    @Test
    void sendMessage_publishesTheStoredEventThatDrivesThePush() {
        chatService.sendMessage(CONVERSATION_ID, new SendMessageRequest("Persze!", "uuid-1"));

        verify(eventPublisher).publishEvent(new ChatMessageStoredEvent(100L));
    }

    @Test
    void sendMessage_toArchivedConversation_isRejected() {
        conversation.setArchivedAt(Instant.now());

        assertThatThrownBy(() -> chatService.sendMessage(CONVERSATION_ID, new SendMessageRequest("Hi", "uuid-1")))
                .isInstanceOf(ConversationArchivedException.class);
        verify(messageRepository, never()).save(any());
    }

    @Test
    void sendMessage_whenChatIsDisabled_isRejected() {
        chatService = new ChatServiceImpl(conversationRepository, messageRepository, participantRepository,
                trainerClientRepository, currentUserProvider, rateLimiter,
                new ChatProperties(false, 2000, 30, 100, 30, 600,
                        Duration.ofMinutes(5), 200, Duration.ofMinutes(2),
                        Duration.ofSeconds(60), Duration.ofMinutes(30), 1, false,
                        Duration.ofHours(24)), eventPublisher);

        assertThatThrownBy(() -> chatService.sendMessage(CONVERSATION_ID, new SendMessageRequest("Hi", "uuid-1")))
                .isInstanceOf(ChatDisabledException.class);
    }

    @Test
    void sendMessage_overTheConfiguredBodyLength_isRejected() {
        String tooLong = "x".repeat(2001);

        assertThatThrownBy(() -> chatService.sendMessage(CONVERSATION_ID, new SendMessageRequest(tooLong, "uuid-1")))
                .isInstanceOf(InvalidMessageBodyException.class);
        verify(messageRepository, never()).save(any());
    }

    @Test
    void sendMessage_byANonParticipant_isNotFound() {
        when(currentUserProvider.getUserId()).thenReturn(999L);
        when(conversationRepository.findByIdForParticipant(CONVERSATION_ID, 999L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> chatService.sendMessage(CONVERSATION_ID, new SendMessageRequest("Hi", "uuid-1")))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    // --- read cursor -------------------------------------------------------

    @Test
    void markRead_advancesTheCursor() {
        conversation.setLastMessageId(50L);

        chatService.markRead(CONVERSATION_ID, 50L);

        assertThat(trainerParticipant.getLastReadMessageId()).isEqualTo(50L);
    }

    @Test
    void markRead_neverMovesTheCursorBackwards() {
        conversation.setLastMessageId(50L);
        trainerParticipant.setLastReadMessageId(40L);

        chatService.markRead(CONVERSATION_ID, 30L);

        assertThat(trainerParticipant.getLastReadMessageId()).isEqualTo(40L);
    }

    @Test
    void markRead_clampsToTheNewestStoredMessage() {
        conversation.setLastMessageId(50L);

        chatService.markRead(CONVERSATION_ID, 9999L);

        assertThat(trainerParticipant.getLastReadMessageId()).isEqualTo(50L);
    }

    @Test
    void markRead_onAnEmptyThread_doesNothing() {
        chatService.markRead(CONVERSATION_ID, 5L);

        assertThat(trainerParticipant.getLastReadMessageId()).isNull();
    }

    // --- keyset paging -----------------------------------------------------

    @Test
    void listMessages_dropsTheProbeRowAndReportsHasMore() {
        // 31 rows come back for a page size of 30: the extra row only signals "more".
        List<ChatMessage> rows = IntStream.range(0, 31)
                .mapToObj(i -> message(100L - i, client, "m" + i, "uuid-" + i))
                .toList();
        when(messageRepository.findLatestPage(eq(CONVERSATION_ID), any(Pageable.class))).thenReturn(rows);

        MessageListResponse response = chatService.listMessages(CONVERSATION_ID, null, null, null);

        assertThat(response.items()).hasSize(30);
        assertThat(response.hasMore()).isTrue();
        assertThat(response.items().getFirst().id()).isEqualTo(100L);
    }

    @Test
    void listMessages_withAfterCursor_stillAnswersNewestFirst() {
        // The gap-fill query walks upwards; the response contract is descending.
        when(messageRepository.findPageAfter(eq(CONVERSATION_ID), eq(40L), any(Pageable.class)))
                .thenReturn(List.of(
                        message(41L, client, "a", "uuid-a"),
                        message(42L, client, "b", "uuid-b")));

        MessageListResponse response = chatService.listMessages(CONVERSATION_ID, null, 40L, null);

        assertThat(response.items()).extracting(m -> m.id()).containsExactly(42L, 41L);
        assertThat(response.hasMore()).isFalse();
    }

    @Test
    void listMessages_cannotAskForMoreThanTheConfiguredMaximum() {
        when(messageRepository.findLatestPage(eq(CONVERSATION_ID), any(Pageable.class))).thenReturn(List.of());

        chatService.listMessages(CONVERSATION_ID, null, null, 5000);

        verify(messageRepository).findLatestPage(eq(CONVERSATION_ID),
                // page size + 1 probe row
                eq(Pageable.ofSize(101)));
    }

    // --- deletion ----------------------------------------------------------

    @Test
    void deleteMessage_tombstonesTheBodyButKeepsTheRow() {
        ChatMessage stored = message(42L, trainer, "oops", "uuid-1");
        when(messageRepository.findById(42L)).thenReturn(Optional.of(stored));

        chatService.deleteMessage(42L);

        assertThat(stored.getDeletedAt()).isNotNull();
        assertThat(stored.getBody()).isNull();
    }

    @Test
    void deleteMessage_someoneElsesMessage_isNotFound() {
        ChatMessage stored = message(42L, client, "not yours", "uuid-1");
        when(messageRepository.findById(42L)).thenReturn(Optional.of(stored));

        assertThatThrownBy(() -> chatService.deleteMessage(42L))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThat(stored.getBody()).isEqualTo("not yours");
    }

    // --- opening and archiving --------------------------------------------

    @Test
    void openConversation_whenOneAlreadyExists_reportsItAsNotCreated() {
        when(trainerClientRepository.findById(RELATIONSHIP_ID)).thenReturn(Optional.of(relationship(TrainerClientStatus.ACTIVE)));
        when(conversationRepository.findByTrainerClientId(RELATIONSHIP_ID)).thenReturn(Optional.of(conversation));

        OpenConversationResult result = chatService.openConversation(RELATIONSHIP_ID);

        assertThat(result.created()).isFalse();
        assertThat(result.conversation().id()).isEqualTo(CONVERSATION_ID);
        verify(conversationRepository, never()).save(any());
    }

    @Test
    void openConversation_createsTheThreadAndBothParticipants() {
        when(trainerClientRepository.findById(RELATIONSHIP_ID)).thenReturn(Optional.of(relationship(TrainerClientStatus.ACTIVE)));
        when(conversationRepository.findByTrainerClientId(RELATIONSHIP_ID)).thenReturn(Optional.empty());

        OpenConversationResult result = chatService.openConversation(RELATIONSHIP_ID);

        assertThat(result.created()).isTrue();
        assertThat(result.conversation().peer().role()).isEqualTo(ChatPeerRole.CLIENT);
        verify(conversationRepository).save(any(ChatConversation.class));

        ArgumentCaptor<List<ChatParticipant>> captor = ArgumentCaptor.captor();
        verify(participantRepository).saveAll(captor.capture());
        assertThat(captor.getValue()).extracting(participant -> participant.getUser().getId())
                .containsExactlyInAnyOrder(TRAINER_ID, CLIENT_ID);
    }

    @Test
    void openConversation_onARevokedRelationship_isNotFound() {
        when(trainerClientRepository.findById(RELATIONSHIP_ID))
                .thenReturn(Optional.of(relationship(TrainerClientStatus.REVOKED)));

        assertThatThrownBy(() -> chatService.openConversation(RELATIONSHIP_ID))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void openConversationWithUser_findsTheRelationshipInEitherDirection() {
        when(trainerClientRepository.findByTrainerIdAndClientIdAndStatus(TRAINER_ID, CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(Optional.empty());
        when(trainerClientRepository.findByTrainerIdAndClientIdAndStatus(CLIENT_ID, TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(Optional.of(relationship(TrainerClientStatus.ACTIVE)));
        when(conversationRepository.findByTrainerClientId(RELATIONSHIP_ID)).thenReturn(Optional.of(conversation));

        assertThat(chatService.openConversationWithUser(CLIENT_ID).created()).isFalse();
    }

    @Test
    void openConversation_seenFromTheClientSide_labelsThePeerAsTrainer() {
        when(currentUserProvider.getUserId()).thenReturn(CLIENT_ID);
        when(trainerClientRepository.findById(RELATIONSHIP_ID)).thenReturn(Optional.of(relationship(TrainerClientStatus.ACTIVE)));
        when(conversationRepository.findByTrainerClientId(RELATIONSHIP_ID)).thenReturn(Optional.of(conversation));

        ConversationResponse response = chatService.openConversation(RELATIONSHIP_ID).conversation();

        assertThat(response.peer().role()).isEqualTo(ChatPeerRole.TRAINER);
        assertThat(response.peer().userId()).isEqualTo(TRAINER_ID);
        assertThat(response.peer().displayName()).isEqualTo("Trainer One");
    }

    @Test
    void archiveForPair_freezesTheLiveThread() {
        when(conversationRepository.findByTrainerIdAndClientIdAndArchivedAtIsNull(TRAINER_ID, CLIENT_ID))
                .thenReturn(List.of(conversation));

        chatService.archiveForPair(TRAINER_ID, CLIENT_ID);

        assertThat(conversation.getArchivedAt()).isNotNull();
    }

    // --- fixtures ----------------------------------------------------------

    private static User user(Long id, String firstName, String lastName) {
        User user = new User();
        user.setId(id);
        user.setFirstName(firstName);
        user.setLastName(lastName);
        user.setEmail(firstName.toLowerCase() + "@example.com");
        return user;
    }

    private ChatMessage message(Long id, User sender, String body, String clientMessageId) {
        ChatMessage message = new ChatMessage();
        message.setId(id);
        message.setConversation(conversation);
        message.setSender(sender);
        message.setBody(body);
        message.setClientMessageId(clientMessageId);
        message.setCreatedAt(Instant.parse("2026-08-02T09:12:44Z"));
        return message;
    }

    private TrainerClient relationship(TrainerClientStatus status) {
        TrainerClient relationship = new TrainerClient();
        relationship.setId(RELATIONSHIP_ID);
        relationship.setTrainer(trainer);
        relationship.setClient(client);
        relationship.setStatus(status);
        return relationship;
    }
}
