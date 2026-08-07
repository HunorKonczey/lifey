package com.lifey.chat.service;

import com.lifey.chat.ChatMessageStoredEvent;
import com.lifey.chat.ChatProperties;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.repository.ChatMessageRepository;
import com.lifey.chat.repository.ChatParticipantRepository;
import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.user.User;
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
    UserSettingsRepository userSettingsRepository;

    @Mock
    PushService pushService;

    @Mock
    ChatEventBus eventBus;

    @Mock
    ChatPresenceRegistry presenceRegistry;

    @Mock
    ChatParticipantRepository participantRepository;

    ChatNotificationServiceImpl notificationService;

    User trainer;
    User client;
    ChatConversation conversation;
    ChatParticipant recipientParticipant;

    @BeforeEach
    void setUp() {
        trainer = user(TRAINER_ID, "Nagy", "Péter");
        client = user(CLIENT_ID, "Kiss", "Anna");

        conversation = new ChatConversation();
        conversation.setId(CONVERSATION_ID);
        conversation.setTrainer(trainer);
        conversation.setClient(client);

        recipientParticipant = new ChatParticipant();
        recipientParticipant.setConversation(conversation);
        recipientParticipant.setUser(client);

        notificationService = new ChatNotificationServiceImpl(
                messageRepository, participantRepository, userSettingsRepository, pushService,
                eventBus, presenceRegistry, properties(), Clock.fixed(NOW, ZoneOffset.UTC));

        when(messageRepository.countUnread(anyLong(), anyLong())).thenReturn(1L);
        when(userSettingsRepository.findByUserId(anyLong())).thenReturn(Optional.empty());
        when(participantRepository.findByConversationIdAndUserId(anyLong(), anyLong()))
                .thenReturn(Optional.of(recipientParticipant));
    }

    private static ChatProperties properties() {
        return new ChatProperties(true, 2000, 30, 100, 30, 600,
                Duration.ofMinutes(5), 200, Duration.ofMinutes(2),
                COALESCE_WINDOW, Duration.ofMinutes(30), 1, false, Duration.ofHours(24),
                8L * 1024 * 1024, 1600, 400, Duration.ofSeconds(2), Duration.ofSeconds(5), 2);
    }

    @Test
    void trainerMessage_pushesTheClientWithTheSenderNameAndBody() {
        storedMessage(trainer, "Holnap 17:00 jó?");

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        PushMessage sent = capturePushTo(CLIENT_ID);
        assertThat(sent.title()).isEqualTo("Nagy Péter");
        assertThat(sent.body()).isEqualTo("Holnap 17:00 jó?");
        assertThat(sent.data()).containsEntry("type", "chat_message")
                .containsEntry("conversationId", "10")
                .containsEntry("messageId", "100");
    }

    @Test
    void clientMessage_pushesTheTrainer() {
        // The symmetry the plan asks for: no branch on who is on which side.
        storedMessage(client, "Persze!");

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        PushMessage sent = capturePushTo(TRAINER_ID);
        assertThat(sent.title()).isEqualTo("Kiss Anna");
        assertThat(sent.body()).isEqualTo("Persze!");
    }

    @Test
    void recipientWithChatPushDisabled_isNotPushed() {
        storedMessage(trainer, "Szia!");
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.of(settings(false, LanguagePreference.SYSTEM)));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushService, never()).sendToUser(anyLong(), any());
    }

    @Test
    void recipientWithoutSettingsRow_stillGetsPushed() {
        storedMessage(trainer, "Szia!");

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushService).sendToUser(anyLong(), any());
    }

    @Test
    void severalUnreadMessages_aggregateTheBody() {
        storedMessage(trainer, "és még valami");
        when(messageRepository.countUnread(CONVERSATION_ID, CLIENT_ID)).thenReturn(3L);

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        assertThat(capturePushTo(CLIENT_ID).body()).isEqualTo("3 new messages");
    }

    @Test
    void aggregatedBodyIsLocalized() {
        storedMessage(trainer, "és még valami");
        when(messageRepository.countUnread(CONVERSATION_ID, CLIENT_ID)).thenReturn(3L);
        when(userSettingsRepository.findByUserId(CLIENT_ID))
                .thenReturn(Optional.of(settings(true, LanguagePreference.HUNGARIAN)));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        assertThat(capturePushTo(CLIENT_ID).body()).isEqualTo("3 új üzenet");
    }

    @Test
    void longBodyIsTruncated() {
        storedMessage(trainer, "x".repeat(200));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        assertThat(capturePushTo(CLIENT_ID).body()).hasSize(120).endsWith("…");
    }

    @Test
    void recipientLookingAtTheThread_isNotPushed() {
        // §5.1 "seen": live stream + presence on this exact thread.
        storedMessage(trainer, "Szia!");
        when(eventBus.isConnected(CLIENT_ID)).thenReturn(true);
        when(presenceRegistry.isViewing(CLIENT_ID, CONVERSATION_ID)).thenReturn(true);

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushService, never()).sendToUser(anyLong(), any());
    }

    @Test
    void recipientLookingAtAnotherThread_isStillPushed() {
        storedMessage(trainer, "Szia!");
        when(eventBus.isConnected(CLIENT_ID)).thenReturn(true);
        when(presenceRegistry.isViewing(CLIENT_ID, CONVERSATION_ID)).thenReturn(false);

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushService).sendToUser(anyLong(), any());
    }

    @Test
    void stalePresenceWithoutAConnection_doesNotSilenceThePush() {
        // A killed app can leave presence behind; without the connection check
        // that user would go quiet until the TTL expired.
        storedMessage(trainer, "Szia!");
        when(eventBus.isConnected(CLIENT_ID)).thenReturn(false);
        when(presenceRegistry.isViewing(CLIENT_ID, CONVERSATION_ID)).thenReturn(true);

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushService).sendToUser(anyLong(), any());
    }

    @Test
    void everyChatPushCarriesAPerThreadCollapseKey() {
        // §5.3 — five messages in one thread are one row in the OS notification
        // centre, not five.
        storedMessage(trainer, "Szia!");

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        assertThat(capturePushTo(CLIENT_ID).collapseKey()).isEqualTo("chat-10");
    }

    @Test
    void aSecondMessageWithinTheCoalesceWindow_isNotPushedAgain() {
        storedMessage(trainer, "és még valami");
        recipientParticipant.setLastNotifiedAt(NOW.minus(COALESCE_WINDOW).plusSeconds(1));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushService, never()).sendToUser(anyLong(), any());
    }

    @Test
    void onceTheWindowHasPassed_thePushGoesOutAgain() {
        storedMessage(trainer, "és még valami");
        recipientParticipant.setLastNotifiedAt(NOW.minus(COALESCE_WINDOW).minusSeconds(1));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushService).sendToUser(anyLong(), any());
    }

    @Test
    void aSentPushOpensTheWindowForTheNextOne() {
        storedMessage(trainer, "Szia!");

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        assertThat(recipientParticipant.getLastNotifiedAt()).isEqualTo(NOW);
    }

    @Test
    void aMutedThread_isNotPushed() {
        storedMessage(trainer, "Szia!");
        recipientParticipant.setMutedUntil(NOW.plusSeconds(60));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushService, never()).sendToUser(anyLong(), any());
    }

    @Test
    void anExpiredMuteIsNoMute() {
        storedMessage(trainer, "Szia!");
        recipientParticipant.setMutedUntil(NOW.minusSeconds(1));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushService).sendToUser(anyLong(), any());
    }

    @Test
    void insideTheQuietHours_noPushGoesOut() {
        // NOW is 12:00 UTC; the recipient is at UTC+2, so their local 14:00
        // falls inside a 13:00–15:00 window.
        storedMessage(trainer, "Szia!");
        client.setUtcOffsetMinutes(120);
        when(userSettingsRepository.findByUserId(CLIENT_ID))
                .thenReturn(Optional.of(quietHours(LocalTime.of(13, 0), LocalTime.of(15, 0))));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushService, never()).sendToUser(anyLong(), any());
    }

    @Test
    void theSameWindowInAnotherTimeZoneDoesNotSilenceThePush() {
        // Identical settings, a recipient in UTC: local 12:00 is outside 13–15.
        storedMessage(trainer, "Szia!");
        client.setUtcOffsetMinutes(0);
        when(userSettingsRepository.findByUserId(CLIENT_ID))
                .thenReturn(Optional.of(quietHours(LocalTime.of(13, 0), LocalTime.of(15, 0))));

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushService).sendToUser(anyLong(), any());
    }

    @Test
    void aMissingMessage_isIgnored() {
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.empty());

        notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID));

        verify(pushService, never()).sendToUser(anyLong(), any());
    }

    @Test
    void aFailureIsSwallowed_soASendNeverFailsBecauseOfANotification() {
        when(messageRepository.findById(MESSAGE_ID)).thenThrow(new IllegalStateException("db down"));

        assertThatCode(() -> notificationService.onMessageStored(new ChatMessageStoredEvent(MESSAGE_ID)))
                .doesNotThrowAnyException();
    }

    // --- fixtures ----------------------------------------------------------

    private void storedMessage(User sender, String body) {
        ChatMessage message = new ChatMessage();
        message.setId(MESSAGE_ID);
        message.setConversation(conversation);
        message.setSender(sender);
        message.setBody(body);
        message.setClientMessageId("uuid-1");
        message.setCreatedAt(Instant.parse("2026-08-06T09:00:00Z"));
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.of(message));
    }

    private PushMessage capturePushTo(Long userId) {
        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.captor();
        verify(pushService).sendToUser(org.mockito.ArgumentMatchers.eq(userId), captor.capture());
        return captor.getValue();
    }

    private static UserSettings quietHours(LocalTime start, LocalTime end) {
        UserSettings settings = settings(true, LanguagePreference.SYSTEM);
        settings.setChatQuietHoursStart(start);
        settings.setChatQuietHoursEnd(end);
        return settings;
    }

    private static UserSettings settings(boolean chatPushEnabled, LanguagePreference language) {
        UserSettings settings = new UserSettings();
        settings.setChatPushEnabled(chatPushEnabled);
        settings.setLanguage(language);
        return settings;
    }

    private static User user(Long id, String firstName, String lastName) {
        User user = new User();
        user.setId(id);
        user.setFirstName(firstName);
        user.setLastName(lastName);
        user.setEmail(id + "@example.com");
        return user;
    }
}
