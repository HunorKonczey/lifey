package com.lifey.push;

import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.user.User;
import com.lifey.workout.session.WorkoutSession;
import com.lifey.workout.session.WorkoutSessionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class WorkoutReminderJobTest {

    private static final Long USER_ID = 1L;
    private static final LocalDate SCHEDULED_FOR = LocalDate.of(2026, 7, 11);

    @Mock
    WorkoutSessionRepository workoutSessionRepository;

    @Mock
    UserSettingsRepository userSettingsRepository;

    @Mock
    PushService pushService;

    User user;
    WorkoutSession session;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(USER_ID);

        session = new WorkoutSession();
        session.setId(30L);
        session.setUser(user);
        session.setScheduledFor(SCHEDULED_FOR);
        session.setTemplateName("Push day");
    }

    private WorkoutReminderJob jobAt(Instant now) {
        return new WorkoutReminderJob(workoutSessionRepository, userSettingsRepository, pushService,
                Clock.fixed(now, ZoneOffset.UTC));
    }

    private void stubCandidates(Instant now) {
        LocalDate from = LocalDate.ofInstant(now, ZoneOffset.UTC).minusDays(1);
        LocalDate to = LocalDate.ofInstant(now, ZoneOffset.UTC).plusDays(1);
        when(workoutSessionRepository.findReminderCandidates(from, to)).thenReturn(List.of(session));
    }

    @Test
    void sends_whenLocalTimePastSendHour_offsetZero() {
        user.setUtcOffsetMinutes(0);
        Instant now = SCHEDULED_FOR.atTime(LocalTime.of(9, 0)).toInstant(ZoneOffset.UTC);
        stubCandidates(now);
        when(userSettingsRepository.findByUserId(USER_ID)).thenReturn(Optional.empty());

        jobAt(now).sendDueReminders();

        verify(pushService).sendToUser(eq(USER_ID), any(PushMessage.class));
        assertThat(session.getReminderSentAt()).isEqualTo(now);
    }

    @Test
    void doesNotSend_whenLocalTimeBeforeSendHour() {
        user.setUtcOffsetMinutes(0);
        Instant now = SCHEDULED_FOR.atTime(LocalTime.of(7, 0)).toInstant(ZoneOffset.UTC);
        stubCandidates(now);

        jobAt(now).sendDueReminders();

        verify(pushService, never()).sendToUser(any(), any());
        assertThat(session.getReminderSentAt()).isNull();
    }

    @Test
    void sends_withPositiveOffset_whenUserLocalTimeIsPastSendHour() {
        // UTC+2 (e.g. Budapest summer): 06:30 UTC is 08:30 local.
        user.setUtcOffsetMinutes(120);
        Instant now = SCHEDULED_FOR.atTime(LocalTime.of(6, 30)).toInstant(ZoneOffset.UTC);
        stubCandidates(now);
        when(userSettingsRepository.findByUserId(USER_ID)).thenReturn(Optional.empty());

        jobAt(now).sendDueReminders();

        verify(pushService).sendToUser(eq(USER_ID), any(PushMessage.class));
    }

    @Test
    void sends_withNegativeOffset_whenUserLocalTimeIsPastSendHour() {
        // UTC-5 (e.g. US Eastern): 13:30 UTC is 08:30 local.
        user.setUtcOffsetMinutes(-300);
        Instant now = SCHEDULED_FOR.atTime(LocalTime.of(13, 30)).toInstant(ZoneOffset.UTC);
        stubCandidates(now);
        when(userSettingsRepository.findByUserId(USER_ID)).thenReturn(Optional.empty());

        jobAt(now).sendDueReminders();

        verify(pushService).sendToUser(eq(USER_ID), any(PushMessage.class));
    }

    @Test
    void doesNotSend_whenScheduledDateIsNotTheUsersLocalToday() {
        // Job downtime: local day has already moved past the scheduled date —
        // reminders must never carry over to the next day.
        user.setUtcOffsetMinutes(0);
        Instant now = SCHEDULED_FOR.plusDays(1).atTime(LocalTime.of(9, 0)).toInstant(ZoneOffset.UTC);
        stubCandidates(now);

        jobAt(now).sendDueReminders();

        verify(pushService, never()).sendToUser(any(), any());
        assertThat(session.getReminderSentAt()).isNull();
    }

    @Test
    void doesNotSend_andDoesNotMarkReminderSentAt_whenUserDisabledTheReminder() {
        user.setUtcOffsetMinutes(0);
        Instant now = SCHEDULED_FOR.atTime(LocalTime.of(9, 0)).toInstant(ZoneOffset.UTC);
        stubCandidates(now);
        UserSettings settings = new UserSettings();
        settings.setWorkoutReminderEnabled(false);
        when(userSettingsRepository.findByUserId(USER_ID)).thenReturn(Optional.of(settings));

        jobAt(now).sendDueReminders();

        verify(pushService, never()).sendToUser(any(), any());
        assertThat(session.getReminderSentAt()).isNull();
    }

    @Test
    void treatsMissingSettingsRowAsEnabled() {
        user.setUtcOffsetMinutes(0);
        Instant now = SCHEDULED_FOR.atTime(LocalTime.of(9, 0)).toInstant(ZoneOffset.UTC);
        stubCandidates(now);
        when(userSettingsRepository.findByUserId(USER_ID)).thenReturn(Optional.empty());

        jobAt(now).sendDueReminders();

        verify(pushService).sendToUser(eq(USER_ID), any(PushMessage.class));
    }

    @Test
    void doesNotSend_andDoesNotMarkReminderSentAt_whenUserAlreadyStartedAWorkoutToday() {
        // Not necessarily this same scheduled occurrence — any session started
        // that local day is enough to suppress the "workout today" nudge.
        user.setUtcOffsetMinutes(0);
        Instant now = SCHEDULED_FOR.atTime(LocalTime.of(9, 0)).toInstant(ZoneOffset.UTC);
        stubCandidates(now);
        when(userSettingsRepository.findByUserId(USER_ID)).thenReturn(Optional.empty());
        when(workoutSessionRepository.existsByUserIdAndDeletedAtIsNullAndStartedAtBetween(
                eq(USER_ID), any(Instant.class), any(Instant.class)))
                .thenReturn(true);

        jobAt(now).sendDueReminders();

        verify(pushService, never()).sendToUser(any(), any());
        assertThat(session.getReminderSentAt()).isNull();
    }

    @Test
    void usesHungarianCopy_whenUsersLanguageIsHungarian() {
        user.setUtcOffsetMinutes(0);
        Instant now = SCHEDULED_FOR.atTime(LocalTime.of(9, 0)).toInstant(ZoneOffset.UTC);
        stubCandidates(now);
        UserSettings settings = new UserSettings();
        settings.setLanguage(LanguagePreference.HUNGARIAN);
        when(userSettingsRepository.findByUserId(USER_ID)).thenReturn(Optional.of(settings));

        jobAt(now).sendDueReminders();

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(USER_ID), captor.capture());
        assertThat(captor.getValue().title()).isEqualTo("Edzés van ma");
    }

    @Test
    void usesEnglishCopy_byDefault() {
        user.setUtcOffsetMinutes(0);
        Instant now = SCHEDULED_FOR.atTime(LocalTime.of(9, 0)).toInstant(ZoneOffset.UTC);
        stubCandidates(now);
        when(userSettingsRepository.findByUserId(USER_ID)).thenReturn(Optional.empty());

        jobAt(now).sendDueReminders();

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(USER_ID), captor.capture());
        assertThat(captor.getValue().title()).isEqualTo("Workout today");
        assertThat(captor.getValue().body()).isEqualTo("Push day");
    }

    @Test
    void messageData_carriesSessionIdAndScheduledForForDeepLinking() {
        user.setUtcOffsetMinutes(0);
        Instant now = SCHEDULED_FOR.atTime(LocalTime.of(9, 0)).toInstant(ZoneOffset.UTC);
        stubCandidates(now);
        when(userSettingsRepository.findByUserId(USER_ID)).thenReturn(Optional.empty());

        jobAt(now).sendDueReminders();

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(USER_ID), captor.capture());
        assertThat(captor.getValue().data())
                .containsEntry("type", "scheduled_workout")
                .containsEntry("sessionId", "30")
                .containsEntry("scheduledFor", "2026-07-11");
    }
}
