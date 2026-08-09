package com.lifey.chat.service;

import com.lifey.chat.ChatMetrics;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import com.lifey.chat.ChatMessageStoredEvent;
import com.lifey.chat.ChatProperties;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.repository.ChatMessageRepository;
import com.lifey.chat.repository.ChatParticipantRepository;
import com.lifey.chat.spi.ChatNotificationPreferences;
import com.lifey.chat.spi.ChatPushNotification;
import com.lifey.chat.spi.ChatPushPrefs;
import com.lifey.chat.spi.ChatPushSender;
import com.lifey.chat.spi.ChatUser;
import com.lifey.chat.spi.ChatUserDirectory;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.mockito.Mockito.mock;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Covers the §5.2 push rules this iteration actually implements: the settings
 * opt-out, the language-dependent copy, the aggregated body once more than one
 * message is unread, and — the important one — that the notification path is
 * symmetric, so the trainer gets pushed exactly like the client.
 *
 * <p>Preferences arrive through {@code ChatNotificationPreferences}, so what a
 * user with <em>no settings row</em> gets is not this class's business any more;
 * that default is pinned in {@code ChatPreferencesAdapterTest}.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ChatNotificationServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;
    private static final Long CONVERSATION_ID = 10L;
    private static final Long MESSAGE_ID = 100L;
    private static final Instant NOW = Instant.parse("2026-08-06T12:00:00Z");
    private static final Duration COALESCE_WINDOW = Duration.ofSeconds(60);

    @Mock
    ChatMessageRepository messageRepository;

    @Mock
    ChatNotificationPreferences preferences;

    @Mock
    ChatUserDirectory userDirectory;

    @Mock
    ChatPushSender pushSender;

    @Mock
    ChatEventBus eventBus;

    @Mock
    ChatPresenceRegistry presenceRegistry;

    @Mock
    ChatParticipantRepository participantRepository;

    ChatNotificationServiceImpl notificationService;

    ChatConversation conversation;
    ChatParticipant recipientParticipant;

    @BeforeEach
    void setUp() {
        conversation = new ChatConversation();
        conversation.setId(CONVERSATION_ID);
        conversation.setTrainerId(TRAINER_ID);
        conversation.setClientId(CLIENT_ID);

        recipientParticipant = new ChatParticipant();
        recipientParticipant.setConversation(conversation);
        recipientParticipant.setUserId(CLIENT_ID);

        notificationService = new ChatNotificationServiceImpl(
                messageRepository, participantRepository, preferences, userDirectory, pushSender,
                eventBus, presenceRegistry, properties(), metrics(), Clock.fixed(NOW, ZoneOffset.UTC));

        when(messageRepository.countUnread(anyLong(), anyLong())).thenReturn(1L);
        when(preferences.load(anyLong())).thenReturn(prefs(true, 0, null, null, false));
        when(participantRepository.findByConversationIdAndUserId(anyLong(), anyLong()))
                .thenReturn(Optional.of(recipientParticipant));
        when(userDirectory.find(TRAINER_ID))
                .thenReturn(Optional.of(new ChatUser(TRAINER_ID, "Nagy Péter", "1@example.com")));
        when(userDirectory.find(CLIENT_ID))
                .thenReturn(Optional.of(new ChatUser(CLIENT_ID, "Kiss Anna", "2@example.com")));
    }

    private static ChatProperties properties() {
        return new ChatProperties(true, 2000, 30, 100, 30, 600,
                Duration.ofMinutes(5), 200, Duration.ofDays(7), Duration.ofMinutes(2),
                COALESCE_WINDOW, Duration.ofMinutes(30), 1, false, Duration.ofHours(24),
                8L * 1024 * 1024, 1600, 400, Duration.ofSeconds(2), Duration.ofSeconds(5), 2);
    }

    @Test
    void trainerMessage_pushesTheClientWithTheSenderNameAndBody() {
        storedMessage(TRAINER_ID, "Holnap 17:00 jó?");

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        ChatPushNotification sent = capturePushTo(CLIENT_ID);
        assertThat(sent.title()).isEqualTo("Nagy Péter");
        assertThat(sent.body()).isEqualTo("Holnap 17:00 jó?");
        assertThat(sent.data()).containsEntry("type", "chat_message")
                .containsEntry("conversationId", "10")
                .containsEntry("messageId", "100");
    }

    @Test
    void clientMessage_pushesTheTrainer() {
        // The symmetry the plan asks for: no branch on who is on which side.
        storedMessage(CLIENT_ID, "Persze!");

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        ChatPushNotification sent = capturePushTo(TRAINER_ID);
        assertThat(sent.title()).isEqualTo("Kiss Anna");
        assertThat(sent.body()).isEqualTo("Persze!");
    }

    @Test
    void recipientWithChatPushDisabled_isNotPushed() {
        storedMessage(TRAINER_ID, "Szia!");
        when(preferences.load(CLIENT_ID)).thenReturn(prefs(false, 0, null, null, false));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushSender, never()).send(anyLong(), any());
    }

    @Test
    void recipientWithDefaultPreferences_isPushed() {
        storedMessage(TRAINER_ID, "Szia!");

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushSender).send(anyLong(), any());
    }

    @Test
    void severalUnreadMessages_aggregateTheBody() {
        storedMessage(TRAINER_ID, "és még valami");
        when(messageRepository.countUnread(CONVERSATION_ID, CLIENT_ID)).thenReturn(3L);

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        assertThat(capturePushTo(CLIENT_ID).body()).isEqualTo("3 new messages");
    }

    @Test
    void aggregatedBodyIsLocalized() {
        storedMessage(TRAINER_ID, "és még valami");
        when(messageRepository.countUnread(CONVERSATION_ID, CLIENT_ID)).thenReturn(3L);
        when(preferences.load(CLIENT_ID)).thenReturn(prefs(true, 0, null, null, true));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        assertThat(capturePushTo(CLIENT_ID).body()).isEqualTo("3 új üzenet");
    }

    @Test
    void longBodyIsTruncated() {
        storedMessage(TRAINER_ID, "x".repeat(200));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        assertThat(capturePushTo(CLIENT_ID).body()).hasSize(120).endsWith("…");
    }

    @Test
    void recipientLookingAtTheThread_isNotPushed() {
        // §5.1 "seen": live stream + presence on this exact thread.
        storedMessage(TRAINER_ID, "Szia!");
        when(eventBus.isConnected(CLIENT_ID)).thenReturn(true);
        when(presenceRegistry.isViewing(CLIENT_ID, CONVERSATION_ID)).thenReturn(true);

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushSender, never()).send(anyLong(), any());
    }

    @Test
    void recipientLookingAtAnotherThread_isStillPushed() {
        storedMessage(TRAINER_ID, "Szia!");
        when(eventBus.isConnected(CLIENT_ID)).thenReturn(true);
        when(presenceRegistry.isViewing(CLIENT_ID, CONVERSATION_ID)).thenReturn(false);

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushSender).send(anyLong(), any());
    }

    @Test
    void stalePresenceWithoutAConnection_doesNotSilenceThePush() {
        // A killed app can leave presence behind; without the connection check
        // that user would go quiet until the TTL expired.
        storedMessage(TRAINER_ID, "Szia!");
        when(eventBus.isConnected(CLIENT_ID)).thenReturn(false);
        when(presenceRegistry.isViewing(CLIENT_ID, CONVERSATION_ID)).thenReturn(true);

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushSender).send(anyLong(), any());
    }

    @Test
    void everyChatPushCarriesAPerThreadCollapseKey() {
        // §5.3 — five messages in one thread are one row in the OS notification
        // centre, not five.
        storedMessage(TRAINER_ID, "Szia!");

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        assertThat(capturePushTo(CLIENT_ID).collapseKey()).isEqualTo("chat-10");
    }

    @Test
    void aSecondMessageWithinTheCoalesceWindow_isNotPushedAgain() {
        storedMessage(TRAINER_ID, "és még valami");
        recipientParticipant.setLastNotifiedAt(NOW.minus(COALESCE_WINDOW).plusSeconds(1));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushSender, never()).send(anyLong(), any());
    }

    @Test
    void onceTheWindowHasPassed_thePushGoesOutAgain() {
        storedMessage(TRAINER_ID, "és még valami");
        recipientParticipant.setLastNotifiedAt(NOW.minus(COALESCE_WINDOW).minusSeconds(1));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushSender).send(anyLong(), any());
    }

    @Test
    void aSentPushOpensTheWindowForTheNextOne() {
        storedMessage(TRAINER_ID, "Szia!");

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        assertThat(recipientParticipant.getLastNotifiedAt()).isEqualTo(NOW);
    }

    @Test
    void aMutedThread_isNotPushed() {
        storedMessage(TRAINER_ID, "Szia!");
        recipientParticipant.setMutedUntil(NOW.plusSeconds(60));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushSender, never()).send(anyLong(), any());
    }

    @Test
    void anExpiredMuteIsNoMute() {
        storedMessage(TRAINER_ID, "Szia!");
        recipientParticipant.setMutedUntil(NOW.minusSeconds(1));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushSender).send(anyLong(), any());
    }

    @Test
    void insideTheQuietHours_noPushGoesOut() {
        // NOW is 12:00 UTC; the recipient is at UTC+2, so their local 14:00
        // falls inside a 13:00–15:00 window.
        storedMessage(TRAINER_ID, "Szia!");
        when(preferences.load(CLIENT_ID))
                .thenReturn(prefs(true, 120, LocalTime.of(13, 0), LocalTime.of(15, 0), false));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushSender, never()).send(anyLong(), any());
    }

    @Test
    void theSameWindowInAnotherTimeZoneDoesNotSilenceThePush() {
        // Identical settings, a recipient in UTC: local 12:00 is outside 13–15.
        storedMessage(TRAINER_ID, "Szia!");
        when(preferences.load(CLIENT_ID))
                .thenReturn(prefs(true, 0, LocalTime.of(13, 0), LocalTime.of(15, 0), false));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushSender).send(anyLong(), any());
    }

    @Test
    void aMissingMessage_isIgnored() {
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.empty());

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushSender, never()).send(anyLong(), any());
    }

    @Test
    void aFailureIsSwallowed_soASendNeverFailsBecauseOfANotification() {
        when(messageRepository.findById(MESSAGE_ID)).thenThrow(new IllegalStateException("db down"));

        assertThatCode(() -> notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID)))
                .doesNotThrowAnyException();
    }

    // --- fixtures ----------------------------------------------------------

    private void storedMessage(Long senderId, String body) {
        ChatMessage message = new ChatMessage();
        message.setId(MESSAGE_ID);
        message.setConversation(conversation);
        message.setSenderId(senderId);
        message.setBody(body);
        message.setClientMessageId("uuid-1");
        message.setCreatedAt(Instant.parse("2026-08-06T09:00:00Z"));
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.of(message));
    }

    private ChatPushNotification capturePushTo(Long userId) {
        ArgumentCaptor<ChatPushNotification> captor = ArgumentCaptor.captor();
        verify(pushSender).send(org.mockito.ArgumentMatchers.eq(userId), captor.capture());
        return captor.getValue();
    }

    private static ChatPushPrefs prefs(boolean pushEnabled, int utcOffsetMinutes,
                                       LocalTime quietStart, LocalTime quietEnd, boolean hungarian) {
        return new ChatPushPrefs(pushEnabled, utcOffsetMinutes, quietStart, quietEnd, hungarian);
    }

    /**
     * Real meters over a {@code SimpleMeterRegistry} rather than a mock: the
     * counters are pre-registered in {@link ChatMetrics}' constructor, and a
     * mock would hide it if that ever stopped happening.
     */
    private static ChatMetrics metrics() {
        return new ChatMetrics(new SimpleMeterRegistry(), mock(ChatEmitterRegistry.class));
    }

}
