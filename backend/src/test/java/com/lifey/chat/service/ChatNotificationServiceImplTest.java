package com.lifey.chat.service;

import com.lifey.chat.ChatMessageStoredEvent;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.repository.ChatMessageRepository;
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

    @Mock
    ChatMessageRepository messageRepository;

    @Mock
    UserSettingsRepository userSettingsRepository;

    @Mock
    PushService pushService;

    @InjectMocks
    ChatNotificationServiceImpl notificationService;

    User trainer;
    User client;
    ChatConversation conversation;

    @BeforeEach
    void setUp() {
        trainer = user(TRAINER_ID, "Nagy", "Péter");
        client = user(CLIENT_ID, "Kiss", "Anna");

        conversation = new ChatConversation();
        conversation.setId(CONVERSATION_ID);
        conversation.setTrainer(trainer);
        conversation.setClient(client);

        when(messageRepository.countUnread(anyLong(), anyLong())).thenReturn(1L);
        when(userSettingsRepository.findByUserId(anyLong())).thenReturn(Optional.empty());
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
