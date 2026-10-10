package com.lifey.trainer;

import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
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
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** When the trainer is told, who is told, and what is left alone (docs/85-trainer-push-plan.md). */
@ExtendWith(MockitoExtension.class)
class ClientMissedWorkoutJobTest {

    // 2026-10-06 (Tuesday) 06:30 UTC; the day before, Monday 2026-10-05, is the day the workout was missed.
    private static final Instant TUESDAY_0630_UTC = Instant.parse("2026-10-06T06:30:00Z");
    private static final LocalDate MONDAY = LocalDate.of(2026, 10, 5);

    @Mock
    WorkoutScheduleRepository workoutScheduleRepository;

    @Mock
    WorkoutSessionRepository workoutSessionRepository;

    @Mock
    UserSettingsRepository userSettingsRepository;

    @Mock
    PushService pushService;

    ClientMissedWorkoutJob jobAt(Instant now) {
        return new ClientMissedWorkoutJob(workoutScheduleRepository, workoutSessionRepository, userSettingsRepository,
                pushService, Clock.fixed(now, ZoneOffset.UTC));
    }

    @BeforeEach
    void noSettingsRowByDefault() {
        org.mockito.Mockito.lenient().when(userSettingsRepository.findByUserId(any())).thenReturn(Optional.empty());
    }

    // ---- isDue ----

    @Test
    void isDue_notBeforeEightLocalTimeOfTheDayAfter() {
        // Trainer at UTC+2: 06:30 UTC is 08:30 local -> due; at UTC+0 it is 06:30 local -> not yet.
        assertThat(ClientMissedWorkoutJob.isDue(occurrence(MONDAY, 120), TUESDAY_0630_UTC)).isTrue();
        assertThat(ClientMissedWorkoutJob.isDue(occurrence(MONDAY, 0), TUESDAY_0630_UTC)).isFalse();
    }

    @Test
    void isDue_notOnTheDayItself_andNotWhenItIsStale() {
        assertThat(ClientMissedWorkoutJob.isDue(occurrence(MONDAY.plusDays(1), 0), TUESDAY_0630_UTC.plusSeconds(3600 * 3))).isFalse();
        // Caught up late the next evening: still announced (the morning slot was missed, e.g. downtime).
        assertThat(ClientMissedWorkoutJob.isDue(occurrence(MONDAY, 0), Instant.parse("2026-10-07T01:00:00Z"))).isTrue();
        // Three days late is the limit, four is stale.
        assertThat(ClientMissedWorkoutJob.isDue(occurrence(MONDAY, 0), Instant.parse("2026-10-08T09:00:00Z"))).isTrue();
        assertThat(ClientMissedWorkoutJob.isDue(occurrence(MONDAY, 0), Instant.parse("2026-10-09T09:00:00Z"))).isFalse();
    }

    // ---- the job ----

    @Test
    void announcesADueMissToItsTrainer_andMarksIt() {
        when(workoutScheduleRepository.findMissedOccurrenceCandidates(any(), any()))
                .thenReturn(List.of(occurrence(MONDAY, 120, 11L, "Anna", 7L)));

        jobAt(TUESDAY_0630_UTC).announceDueMisses();

        ArgumentCaptor<PushMessage> message = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(9L), message.capture());
        assertThat(message.getValue().body()).isEqualTo("Anna missed Push day (Monday)");
        verify(workoutSessionRepository).markMissedNotified(List.of(7L), TUESDAY_0630_UTC);
    }

    @Test
    void doesNothingBeforeTheSendTime_andMarksNothing() {
        when(workoutScheduleRepository.findMissedOccurrenceCandidates(any(), any()))
                .thenReturn(List.of(occurrence(MONDAY, 0, 11L, "Anna", 7L)));

        jobAt(TUESDAY_0630_UTC).announceDueMisses();

        verify(pushService, never()).sendToUser(any(), any());
        verify(workoutSessionRepository, never()).markMissedNotified(any(), any());
    }

    @Test
    void severalClientsOfOneTrainer_areOnePush_andEveryOccurrenceIsMarked() {
        when(workoutScheduleRepository.findMissedOccurrenceCandidates(any(), any())).thenReturn(List.of(
                occurrence(MONDAY, 120, 11L, "Anna", 7L),
                occurrence(MONDAY, 120, 12L, "Bela", 8L)));

        jobAt(TUESDAY_0630_UTC).announceDueMisses();

        ArgumentCaptor<PushMessage> message = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(9L), message.capture());
        assertThat(message.getValue().body()).isEqualTo("2 clients missed a workout: Anna, Bela");
        verify(workoutSessionRepository).markMissedNotified(List.of(7L, 8L), TUESDAY_0630_UTC);
    }

    @Test
    void twoTrainers_eachGetTheirOwnPush() {
        when(workoutScheduleRepository.findMissedOccurrenceCandidates(any(), any())).thenReturn(List.of(
                occurrence(MONDAY, 120, 11L, "Anna", 7L),
                new MissedOccurrence(8L, MONDAY, "Pull day", 10L, 120, 12L, "bela@example.com", "Bela", null)));

        jobAt(TUESDAY_0630_UTC).announceDueMisses();

        verify(pushService).sendToUser(eq(9L), any());
        verify(pushService).sendToUser(eq(10L), any());
    }

    @Test
    void aTrainerWhoSwitchedThePushOff_getsNothing_butTheMissIsStillMarked() {
        UserSettings off = new UserSettings();
        off.setClientMissedWorkoutPushEnabled(false);
        when(userSettingsRepository.findByUserId(9L)).thenReturn(Optional.of(off));
        when(workoutScheduleRepository.findMissedOccurrenceCandidates(any(), any()))
                .thenReturn(List.of(occurrence(MONDAY, 120, 11L, "Anna", 7L)));

        jobAt(TUESDAY_0630_UTC).announceDueMisses();

        verify(pushService, never()).sendToUser(any(), any());
        // Marked, so switching the push on tomorrow does not announce yesterday.
        verify(workoutSessionRepository).markMissedNotified(List.of(7L), TUESDAY_0630_UTC);
    }

    @Test
    void theMessageIsInTheTrainersLanguage() {
        UserSettings hungarian = new UserSettings();
        hungarian.setLanguage(LanguagePreference.HUNGARIAN);
        when(userSettingsRepository.findByUserId(9L)).thenReturn(Optional.of(hungarian));
        when(workoutScheduleRepository.findMissedOccurrenceCandidates(any(), any()))
                .thenReturn(List.of(occurrence(MONDAY, 120, 11L, "Anna", 7L)));

        jobAt(TUESDAY_0630_UTC).announceDueMisses();

        ArgumentCaptor<PushMessage> message = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(9L), message.capture());
        assertThat(message.getValue().title()).isEqualTo("Kihagyott edzés");
    }

    private static MissedOccurrence occurrence(LocalDate day, int trainerOffsetMinutes) {
        return occurrence(day, trainerOffsetMinutes, 11L, "Anna", 7L);
    }

    private static MissedOccurrence occurrence(LocalDate day, int trainerOffsetMinutes, Long clientId, String name, Long sessionId) {
        return new MissedOccurrence(sessionId, day, "Push day", 9L, trainerOffsetMinutes, clientId, name + "@example.com", name, null);
    }
}
