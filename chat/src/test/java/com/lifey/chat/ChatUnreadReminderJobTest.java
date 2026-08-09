package com.lifey.chat;

import com.lifey.chat.service.ChatEmitterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.repository.ChatMessageRepository;
import com.lifey.chat.repository.ChatParticipantRepository;
import com.lifey.chat.spi.ChatMailSender;
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
import java.util.List;
import java.util.Optional;

import static org.mockito.Mockito.mock;
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
    ChatNotificationPreferences preferences;

    @Mock
    ChatUserDirectory userDirectory;

    @Mock
    ChatPushSender pushSender;

    @Mock
    ChatMailSender mailSender;

    ChatUnreadReminderJob job;

    ChatParticipant clientParticipant;

    @BeforeEach
    void setUp() {
        ChatConversation conversation = new ChatConversation();
        conversation.setId(CONVERSATION_ID);
        conversation.setTrainerId(TRAINER_ID);
        conversation.setClientId(CLIENT_ID);

        clientParticipant = new ChatParticipant();
        clientParticipant.setConversation(conversation);
        clientParticipant.setUserId(CLIENT_ID);

        job = newJob(false);

        when(participantRepository.findReminderCandidates(any())).thenReturn(List.of(clientParticipant));
        when(participantRepository.findAllForUser(CLIENT_ID)).thenReturn(List.of(clientParticipant));
        when(messageRepository.countUnread(CONVERSATION_ID, CLIENT_ID)).thenReturn(2L);
        when(preferences.load(anyLong())).thenReturn(prefs(true, 0, null, null, false));
        // Hungarian name order, same as the other chat fixtures: family name first.
        when(userDirectory.find(TRAINER_ID))
                .thenReturn(Optional.of(new ChatUser(TRAINER_ID, "Nagy Péter", "user1@example.com")));
        when(pushSender.hasRegisteredDevice(anyLong())).thenReturn(true);
    }

    private ChatUnreadReminderJob newJob(boolean emailFallbackEnabled) {
        ChatProperties properties = new ChatProperties(true, 2000, 30, 100, 30, 600,
                Duration.ofMinutes(5), 200, Duration.ofDays(7), Duration.ofMinutes(2),
                Duration.ofSeconds(60), Duration.ofMinutes(30), 1,
                emailFallbackEnabled, Duration.ofHours(24), 8L * 1024 * 1024, 1600, 400, Duration.ofSeconds(2), Duration.ofSeconds(5), 2);
        return new ChatUnreadReminderJob(participantRepository, messageRepository, preferences,
                userDirectory, pushSender, mailSender, properties, metrics(),
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    void anUnreadThreadIsRemindedOnceWithTheSendersName() {
        job.sendDueReminders();

        ChatPushNotification sent = capturePushTo(CLIENT_ID);
        assertThat(sent.body()).isEqualTo("You have 2 unread messages from Nagy Péter");
        assertThat(sent.data()).containsEntry("type", "chat_reminder");
        // One reminder row that replaces the previous one, not a new line daily.
        assertThat(sent.collapseKey()).isEqualTo("chat-reminder");
    }

    @Test
    void theReminderIsLocalized() {
        when(preferences.load(CLIENT_ID)).thenReturn(prefs(true, 0, null, null, true));

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

        verify(pushSender, never()).send(anyLong(), any());
    }

    @Test
    void onceADayHasPassedTheCapResets() {
        clientParticipant.setLastRemindedAt(NOW.minus(Duration.ofHours(25)));

        job.sendDueReminders();

        verify(pushSender).send(eq(CLIENT_ID), any());
    }

    @Test
    void chatPushDisabledSilencesTheReminderToo() {
        when(preferences.load(CLIENT_ID)).thenReturn(prefs(false, 0, null, null, false));

        job.sendDueReminders();

        verify(pushSender, never()).send(anyLong(), any());
    }

    @Test
    void insideTheQuietHoursTheReminderIsDeferred_notCancelled() {
        when(preferences.load(CLIENT_ID))
                .thenReturn(prefs(true, 120, LocalTime.of(13, 0), LocalTime.of(15, 0), false));

        job.sendDueReminders();

        verify(pushSender, never()).send(anyLong(), any());
        // Nothing was stamped, so the next tick after the window ends will find
        // the same unread messages and send.
        assertThat(clientParticipant.getLastRemindedAt()).isNull();
    }

    @Test
    void aMutedThreadIsNotWorkedAroundByTheReminder() {
        clientParticipant.setMutedUntil(NOW.plus(Duration.ofHours(1)));

        job.sendDueReminders();

        verify(pushSender, never()).send(anyLong(), any());
    }

    @Test
    void aThreadThatWasReadInTheMeantimeIsSkipped() {
        when(messageRepository.countUnread(CONVERSATION_ID, CLIENT_ID)).thenReturn(0L);

        job.sendDueReminders();

        verify(pushSender, never()).send(anyLong(), any());
    }

    @Test
    void withTheFlagOffThereIsNoEmailEvenWithoutAPushDevice() {
        when(pushSender.hasRegisteredDevice(CLIENT_ID)).thenReturn(false);

        job.sendDueReminders();

        verify(mailSender, never()).sendUnreadChatEmail(anyLong(), anyLong(), any());
        verify(pushSender).send(eq(CLIENT_ID), any());
    }

    @Test
    void withTheFlagOnAUserWithNoDeviceGetsTheEmailInstead() {
        job = newJob(true);
        when(pushSender.hasRegisteredDevice(CLIENT_ID)).thenReturn(false);

        job.sendDueReminders();

        verify(mailSender).sendUnreadChatEmail(CLIENT_ID, 2L, "Nagy Péter");
        verify(pushSender, never()).send(anyLong(), any());
    }

    @Test
    void aUserWithADeviceKeepsGettingThePushEvenWithTheFlagOn() {
        job = newJob(true);

        job.sendDueReminders();

        verify(mailSender, never()).sendUnreadChatEmail(anyLong(), anyLong(), any());
        verify(pushSender).send(eq(CLIENT_ID), any());
    }

    @Test
    void withTheFlagOnAndARecentPushTheEmailWaitsForItsOwnWindow() {
        job = newJob(true);
        when(pushSender.hasRegisteredDevice(CLIENT_ID)).thenReturn(false);
        clientParticipant.setLastNotifiedAt(NOW.minus(Duration.ofHours(2)));

        job.sendDueReminders();

        verify(mailSender, never()).sendUnreadChatEmail(anyLong(), anyLong(), any());
    }

    private ChatPushNotification capturePushTo(Long userId) {
        ArgumentCaptor<ChatPushNotification> captor = ArgumentCaptor.captor();
        verify(pushSender).send(eq(userId), captor.capture());
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
