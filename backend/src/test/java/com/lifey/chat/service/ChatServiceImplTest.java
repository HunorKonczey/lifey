package com.lifey.chat.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.chat.ChatMessageDeletedEvent;
import com.lifey.chat.ChatMessageStoredEvent;
import com.lifey.chat.ChatProperties;
import com.lifey.chat.dto.ChatPeerRole;
import com.lifey.chat.dto.ConversationResponse;
import com.lifey.chat.dto.MessageListResponse;
import com.lifey.chat.dto.SendMessageRequest;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.entity.ChatMessageAttachment;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.exception.AttachmentTooLargeException;
import com.lifey.chat.exception.ChatDisabledException;
import com.lifey.chat.exception.ConversationArchivedException;
import com.lifey.chat.exception.InvalidMessageBodyException;
import com.lifey.chat.repository.ChatConversationRepository;
import com.lifey.chat.repository.ChatMessageAttachmentRepository;
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
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.mock.web.MockMultipartFile;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
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
    ChatMessageAttachmentRepository attachmentRepository;

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
            Duration.ofSeconds(60), Duration.ofMinutes(30), 1, false, Duration.ofHours(24),
            8L * 1024 * 1024, 1600, 400, Duration.ofSeconds(2), Duration.ofSeconds(5), 2);

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

        chatService = new ChatServiceImpl(conversationRepository, messageRepository, attachmentRepository,
                participantRepository, trainerClientRepository, currentUserProvider, rateLimiter, properties,
                eventPublisher);

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
        chatService = new ChatServiceImpl(conversationRepository, messageRepository, attachmentRepository,
                participantRepository, trainerClientRepository, currentUserProvider, rateLimiter,
                new ChatProperties(false, 2000, 30, 100, 30, 600,
                        Duration.ofMinutes(5), 200, Duration.ofMinutes(2),
                        Duration.ofSeconds(60), Duration.ofMinutes(30), 1, false,
                        Duration.ofHours(24), 8L * 1024 * 1024, 1600, 400, Duration.ofSeconds(2), Duration.ofSeconds(5), 2), eventPublisher);

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

    // --- search (I6) --------------------------------------------------------

    @Test
    void searchMessages_pagesLikeTheThreadDoes() {
        when(messageRepository.searchInConversation(eq(CONVERSATION_ID), anyString(), eq(null), any()))
                .thenReturn(List.of(message(40L, trainer, "lábnap", "uuid-1")));

        MessageListResponse result = chatService.searchMessages(CONVERSATION_ID, "lábnap", null, null);

        assertThat(result.items()).hasSize(1);
        assertThat(result.hasMore()).isFalse();
        verify(messageRepository).searchInConversation(eq(CONVERSATION_ID), eq("%lábnap%"), eq(null),
                // Page size + 1 probe row, the same "is there more?" trick the thread uses.
                eq(PageRequest.of(0, 31)));
    }

    @Test
    void searchMessages_extraRowMeansThereIsMore() {
        List<ChatMessage> rows = IntStream.rangeClosed(1, 31)
                .mapToObj(i -> message((long) i, trainer, "hit " + i, "uuid-" + i))
                .toList();
        when(messageRepository.searchInConversation(eq(CONVERSATION_ID), anyString(), any(), any()))
                .thenReturn(rows);

        MessageListResponse result = chatService.searchMessages(CONVERSATION_ID, "hit", null, null);

        assertThat(result.items()).hasSize(30);
        assertThat(result.hasMore()).isTrue();
    }

    @Test
    void searchMessages_escapesWildcards_soAPercentSignIsLookedForLiterally() {
        chatService.searchMessages(CONVERSATION_ID, "50% _ !", null, null);

        // Unescaped, "%" would match every message in the thread.
        verify(messageRepository).searchInConversation(eq(CONVERSATION_ID), eq("%50!% !_ !!%"), any(), any());
    }

    @Test
    void searchMessages_tooShortOrBlankTerm_isAnEmptyPageRatherThanAnError() {
        for (String term : new String[]{null, "", "  ", "a"}) {
            MessageListResponse result = chatService.searchMessages(CONVERSATION_ID, term, null, null);

            // The clients search as you type: the first keystroke is a normal
            // request, not a mistake worth a 400.
            assertThat(result.items()).isEmpty();
            assertThat(result.hasMore()).isFalse();
        }
        verify(messageRepository, never()).searchInConversation(anyLong(), anyString(), any(), any());
    }

    @Test
    void searchMessages_isTrimmed_soATrailingSpaceIsNotPartOfTheTerm() {
        chatService.searchMessages(CONVERSATION_ID, "  lábnap  ", null, null);

        verify(messageRepository).searchInConversation(eq(CONVERSATION_ID), eq("%lábnap%"), any(), any());
    }

    @Test
    void searchMessages_inSomeoneElsesThread_isNotFound() {
        when(conversationRepository.findByIdForParticipant(CONVERSATION_ID, TRAINER_ID))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> chatService.searchMessages(CONVERSATION_ID, "lábnap", null, null))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(messageRepository, never()).searchInConversation(anyLong(), anyString(), any(), any());
    }

    // --- image attachments -------------------------------------------------

    @Test
    void sendMessage_withImage_storesTheBytesAndTheShapeToReserve() {
        var result = chatService.sendMessage(CONVERSATION_ID, "Nézd meg a tartást", "uuid-1", jpeg(200, 120));

        assertThat(result.created()).isTrue();
        assertThat(result.message().body()).isEqualTo("Nézd meg a tartást");
        // Dimensions travel on the message so a client can size the box before
        // it downloads a single byte.
        assertThat(result.message().attachment()).isNotNull();
        assertThat(result.message().attachment().width()).isEqualTo(200);
        assertThat(result.message().attachment().height()).isEqualTo(120);
        assertThat(result.message().attachment().byteSize()).isPositive();

        ArgumentCaptor<ChatMessageAttachment> captor = ArgumentCaptor.captor();
        verify(attachmentRepository).save(captor.capture());
        assertThat(captor.getValue().getImage()).isNotEmpty();
        assertThat(captor.getValue().getThumbnail()).isNotEmpty();
        assertThat(captor.getValue().getContentType()).isEqualTo("image/jpeg");
    }

    @Test
    void sendMessage_imageWithNoCaption_isAWholeMessage() {
        var result = chatService.sendMessage(CONVERSATION_ID, "   ", "uuid-1", jpeg(64, 64));

        assertThat(result.message().body()).isNull();
        assertThat(result.message().attachment()).isNotNull();
    }

    @Test
    void sendMessage_neitherTextNorImage_isRejected() {
        assertThatThrownBy(() -> chatService.sendMessage(CONVERSATION_ID, "  ", "uuid-1", null))
                .isInstanceOf(InvalidMessageBodyException.class);
    }

    @Test
    void sendMessage_oversizeImage_isRejectedBeforeAnythingIsStored() {
        MockMultipartFile huge = new MockMultipartFile(
                "file", "big.jpg", "image/jpeg", new byte[(int) properties.attachmentMaxBytes() + 1]);

        assertThatThrownBy(() -> chatService.sendMessage(CONVERSATION_ID, "", "uuid-1", huge))
                .isInstanceOf(AttachmentTooLargeException.class);
        verify(messageRepository, never()).save(any());
        verify(attachmentRepository, never()).save(any());
    }

    @Test
    void sendMessage_replayedImageSend_doesNotUploadAgain() {
        ChatMessage stored = message(42L, trainer, null, "uuid-1");
        when(messageRepository.findByConversationIdAndClientMessageId(CONVERSATION_ID, "uuid-1"))
                .thenReturn(Optional.of(stored));

        var result = chatService.sendMessage(CONVERSATION_ID, "", "uuid-1", jpeg(64, 64));

        assertThat(result.created()).isFalse();
        verify(attachmentRepository, never()).save(any());
    }

    @Test
    void findAttachment_isGuardedByTheThread_notBySender() {
        ChatMessage stored = message(42L, client, null, "uuid-1");
        stored.setAttachmentWidth(64);
        when(messageRepository.findById(42L)).thenReturn(Optional.of(stored));
        when(attachmentRepository.findByMessageId(42L)).thenReturn(Optional.of(new ChatMessageAttachment()));

        // The trainer did not send it, but they are in the conversation.
        assertThat(chatService.findAttachment(42L)).isNotNull();
    }

    @Test
    void findAttachment_outsideTheConversation_isNotFound() {
        ChatMessage stored = message(42L, client, null, "uuid-1");
        when(messageRepository.findById(42L)).thenReturn(Optional.of(stored));
        when(conversationRepository.findByIdForParticipant(CONVERSATION_ID, TRAINER_ID))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> chatService.findAttachment(42L))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(attachmentRepository, never()).findByMessageId(anyLong());
    }

    // --- deletion ----------------------------------------------------------

    @Test
    void deleteMessage_tombstonesTheBodyButKeepsTheRow() {
        ChatMessage stored = message(42L, trainer, "oops", "uuid-1");
        when(messageRepository.findById(42L)).thenReturn(Optional.of(stored));

        chatService.deleteMessage(42L);

        assertThat(stored.getDeletedAt()).isNotNull();
        assertThat(stored.getBody()).isNull();
        // The peer may already be showing the text, and their gap fill only
        // walks forward — without this frame the tombstone never reaches them.
        verify(eventPublisher).publishEvent(new ChatMessageDeletedEvent(42L));
    }

    @Test
    void deleteMessage_replayedDeletion_isNotAnnouncedTwice() {
        ChatMessage stored = message(42L, trainer, null, "uuid-1");
        stored.setDeletedAt(Instant.parse("2026-08-07T09:00:00Z"));
        when(messageRepository.findById(42L)).thenReturn(Optional.of(stored));

        chatService.deleteMessage(42L);

        assertThat(stored.getDeletedAt()).isEqualTo(Instant.parse("2026-08-07T09:00:00Z"));
        verify(eventPublisher, never()).publishEvent(any(ChatMessageDeletedEvent.class));
    }

    @Test
    void deleteMessage_withImage_removesThePictureToo() {
        ChatMessage stored = message(42L, trainer, "oops", "uuid-1");
        stored.setAttachmentWidth(200);
        stored.setAttachmentHeight(120);
        stored.setAttachmentByteSize(4096);
        when(messageRepository.findById(42L)).thenReturn(Optional.of(stored));

        chatService.deleteMessage(42L);

        // "Deleted" that left the image downloadable would be a lie.
        verify(attachmentRepository).deleteByMessageId(42L);
        assertThat(stored.hasAttachment()).isFalse();
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

    /** A real, decodable JPEG — the service validates by decoding, so bytes won't do. */
    private static MockMultipartFile jpeg(int width, int height) {
        try {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            ImageIO.write(new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB), "jpg", out);
            return new MockMultipartFile("file", "photo.jpg", "image/jpeg", out.toByteArray());
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
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
