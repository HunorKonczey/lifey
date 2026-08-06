package com.lifey.chat;

import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.repository.ChatMessageRepository;
import com.lifey.chat.repository.ChatParticipantRepository;
import com.lifey.mail.service.MailService;
import com.lifey.push.PushDevice;
import com.lifey.push.PushDeviceRepository;
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
 * §5.4 — the last line of defence. What matters here is restraint: it must fire
 * for genuinely missed messages, and must not become a second notification
 * channel that fires alongside every push.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ChatUnreadReminderJobTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;
    private static final Long CONVERSATION_ID = 10L;
    private static final Instant NOW = Instant.parse("2026-08-06T12:00:00Z");

    @Mock
    ChatParticipantRepository participantRepository;

    @Mock
    ChatMessageRepository messageRepository;

    @Mock
    UserSettingsRepository userSettingsRepository;

    @Mock
    PushDeviceRepository pushDeviceRepository;

    @Mock
    PushService pushService;

    @Mock
    MailService mailService;

    ChatUnreadReminderJob job;

    User trainer;
    User client;
    ChatParticipant clientParticipant;

    @BeforeEach
    void setUp() {
        trainer = user(TRAINER_ID, "Nagy", "Péter");
        client = user(CLIENT_ID, "Kiss", "Anna");

        ChatConversation conversation = new ChatConversation();
        conversation.setId(CONVERSATION_ID);
        conversation.setTrainer(trainer);
        conversation.setClient(client);

        clientParticipant = new ChatParticipant();
        clientParticipant.setConversation(conversation);
        clientParticipant.setUser(client);

        job = newJob(false);

        when(participantRepository.findReminderCandidates(any())).thenReturn(List.of(clientParticipant));
        when(participantRepository.findAllForUser(CLIENT_ID)).thenReturn(List.of(clientParticipant));
        when(messageRepository.countUnread(CONVERSATION_ID, CLIENT_ID)).thenReturn(2L);
        when(userSettingsRepository.findByUserId(anyLong())).thenReturn(Optional.empty());
        when(pushDeviceRepository.findAllByUserIdAndDeletedAtIsNull(anyLong()))
                .thenReturn(List.of(new PushDevice()));
    }

    private ChatUnreadReminderJob newJob(boolean emailFallbackEnabled) {
        ChatProperties properties = new ChatProperties(true, 2000, 30, 100, 30, 600,
                Duration.ofMinutes(5), 200, Duration.ofMinutes(2),
                Duration.ofSeconds(60), Duration.ofMinutes(30), 1,
                emailFallbackEnabled, Duration.ofHours(24));
        return new ChatUnreadReminderJob(participantRepository, messageRepository, userSettingsRepository,
                pushDeviceRepository, pushService, mailService, properties, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    void anUnreadThreadIsRemindedOnceWithTheSendersName() {
        job.sendDueReminders();

        PushMessage sent = capturePushTo(CLIENT_ID);
        assertThat(sent.body()).isEqualTo("You have 2 unread messages from Nagy Péter");
        assertThat(sent.data()).containsEntry("type", "chat_reminder");
        // One reminder row that replaces the previous one, not a new line daily.
        assertThat(sent.collapseKey()).isEqualTo("chat-reminder");
    }

    @Test
    void theReminderIsLocalized() {
        when(userSettingsRepository.findByUserId(CLIENT_ID))
                .thenReturn(Optional.of(settings(true, LanguagePreference.HUNGARIAN)));

        job.sendDueReminders();

        assertThat(capturePushTo(CLIENT_ID).body()).isEqualTo("2 olvasatlan üzeneted van tőle: Nagy Péter");
    }

    @Test
    void sendingARemindersMarksEveryThreadOfThatUser() {
        // The cap is per user, so the stamp has to land where any later run
        // will see it, whichever thread happens to be the candidate then.
        job.sendDueReminders();

        assertThat(clientParticipant.getLastRemindedAt()).isEqualTo(NOW);
    }

    @Test
    void aUserRemindedWithinTheDayIsNotRemindedAgain() {
        clientParticipant.setLastRemindedAt(NOW.minus(Duration.ofHours(23)));

        job.sendDueReminders();

        verify(pushService, never()).sendToUser(anyLong(), any());
    }

    @Test
    void onceADayHasPassedTheCapResets() {
        clientParticipant.setLastRemindedAt(NOW.minus(Duration.ofHours(25)));

        job.sendDueReminders();

        verify(pushService).sendToUser(eq(CLIENT_ID), any());
    }

    @Test
    void chatPushDisabledSilencesTheReminderToo() {
        when(userSettingsRepository.findByUserId(CLIENT_ID))
                .thenReturn(Optional.of(settings(false, LanguagePreference.SYSTEM)));

        job.sendDueReminders();

        verify(pushService, never()).sendToUser(anyLong(), any());
    }

    @Test
    void insideTheQuietHoursTheReminderIsDeferred_notCancelled() {
        client.setUtcOffsetMinutes(120);
        UserSettings settings = settings(true, LanguagePreference.SYSTEM);
        settings.setChatQuietHoursStart(LocalTime.of(13, 0));
        settings.setChatQuietHoursEnd(LocalTime.of(15, 0));
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.of(settings));

        job.sendDueReminders();

        verify(pushService, never()).sendToUser(anyLong(), any());
        // Nothing was stamped, so the next tick after the window ends will find
        // the same unread messages and send.
        assertThat(clientParticipant.getLastRemindedAt()).isNull();
    }

    @Test
    void aMutedThreadIsNotWorkedAroundByTheReminder() {
        clientParticipant.setMutedUntil(NOW.plus(Duration.ofHours(1)));

        job.sendDueReminders();

        verify(pushService, never()).sendToUser(anyLong(), any());
    }

    @Test
    void aThreadThatWasReadInTheMeantimeIsSkipped() {
        when(messageRepository.countUnread(CONVERSATION_ID, CLIENT_ID)).thenReturn(0L);

        job.sendDueReminders();

        verify(pushService, never()).sendToUser(anyLong(), any());
    }

    @Test
    void withTheFlagOffThereIsNoEmailEvenWithoutAPushDevice() {
        when(pushDeviceRepository.findAllByUserIdAndDeletedAtIsNull(CLIENT_ID)).thenReturn(List.of());

        job.sendDueReminders();

        verify(mailService, never()).sendUnreadChatEmail(any(), anyLong(), any());
        verify(pushService).sendToUser(eq(CLIENT_ID), any());
    }

    @Test
    void withTheFlagOnAUserWithNoDeviceGetsTheEmailInstead() {
        job = newJob(true);
        when(pushDeviceRepository.findAllByUserIdAndDeletedAtIsNull(CLIENT_ID)).thenReturn(List.of());

        job.sendDueReminders();

        verify(mailService).sendUnreadChatEmail(client, 2L, "Nagy Péter");
        verify(pushService, never()).sendToUser(anyLong(), any());
    }

    @Test
    void aUserWithADeviceKeepsGettingThePushEvenWithTheFlagOn() {
        job = newJob(true);

        job.sendDueReminders();

        verify(mailService, never()).sendUnreadChatEmail(any(), anyLong(), any());
        verify(pushService).sendToUser(eq(CLIENT_ID), any());
    }

    @Test
    void withTheFlagOnAndARecentPushTheEmailWaitsForItsOwnWindow() {
        job = newJob(true);
        when(pushDeviceRepository.findAllByUserIdAndDeletedAtIsNull(CLIENT_ID)).thenReturn(List.of());
        clientParticipant.setLastNotifiedAt(NOW.minus(Duration.ofHours(2)));

        job.sendDueReminders();

        verify(mailService, never()).sendUnreadChatEmail(any(), anyLong(), any());
    }

    private PushMessage capturePushTo(Long userId) {
        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.captor();
        verify(pushService).sendToUser(eq(userId), captor.capture());
        return captor.getValue();
    }

    private static UserSettings settings(boolean chatPushEnabled, LanguagePreference language) {
        UserSettings settings = new UserSettings();
        settings.setChatPushEnabled(chatPushEnabled);
        settings.setLanguage(language);
        return settings;
    }

    /** Hungarian name order, same as the other chat fixtures: family name first. */
    private static User user(Long id, String firstName, String lastName) {
        User user = new User();
        user.setId(id);
        user.setEmail("user" + id + "@example.com");
        user.setFirstName(firstName);
        user.setLastName(lastName);
        return user;
    }
}
