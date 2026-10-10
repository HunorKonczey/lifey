package com.lifey.trainer;

import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.weight.WeightEntryRepository;
import com.lifey.weight.WeightLoggedEvent;
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
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** "A client logged this week's weigh-in": the first entry of the client's week, in the current week (docs/85-trainer-push-plan.md). */
@ExtendWith(MockitoExtension.class)
class ClientWeighInPushListenerTest {

    private static final Long CLIENT_ID = 5L;
    // Wednesday 2026-10-07 12:00 UTC; that week is Monday 2026-10-05 .. Sunday 2026-10-11.
    private static final Instant NOW = Instant.parse("2026-10-07T12:00:00Z");
    private static final LocalDate MONDAY = LocalDate.of(2026, 10, 5);
    private static final LocalDate SUNDAY = LocalDate.of(2026, 10, 11);

    @Mock
    UserRepository userRepository;

    @Mock
    WeightEntryRepository weightEntryRepository;

    @Mock
    TrainerClientRepository trainerClientRepository;

    @Mock
    UserSettingsRepository userSettingsRepository;

    @Mock
    PushService pushService;

    ClientWeighInPushListener listener;
    User client;

    @BeforeEach
    void setUp() {
        listener = new ClientWeighInPushListener(userRepository, weightEntryRepository, trainerClientRepository,
                userSettingsRepository, pushService, Clock.fixed(NOW, ZoneOffset.UTC));
        client = new User();
        client.setEmail("anna@example.com");
        client.setFirstName("Anna");
        lenient().when(userRepository.findById(CLIENT_ID)).thenReturn(Optional.of(client));
        lenient().when(weightEntryRepository.countByUserIdAndDeletedAtIsNullAndDateBetween(CLIENT_ID, MONDAY, SUNDAY)).thenReturn(1L);
        lenient().when(trainerClientRepository.findTrainerIdsByClientIdAndStatus(CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(9L));
        lenient().when(userSettingsRepository.findByUserId(any())).thenReturn(Optional.empty());
    }

    @Test
    void theFirstWeighInOfTheWeek_tellsTheTrainer() {
        listener.onWeightLogged(new WeightLoggedEvent(CLIENT_ID, LocalDate.of(2026, 10, 7), 82.43));

        ArgumentCaptor<PushMessage> message = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(9L), message.capture());
        assertThat(message.getValue().title()).isEqualTo("Weekly weigh-in");
        assertThat(message.getValue().body()).isEqualTo("Anna logged this week's weigh-in: 82.4 kg");
        assertThat(message.getValue().data()).containsEntry("type", "client_weigh_in").containsEntry("clientId", "5");
    }

    @Test
    void aSecondWeighInInTheSameWeek_sendsNothing() {
        when(weightEntryRepository.countByUserIdAndDeletedAtIsNullAndDateBetween(CLIENT_ID, MONDAY, SUNDAY)).thenReturn(2L);

        listener.onWeightLogged(new WeightLoggedEvent(CLIENT_ID, LocalDate.of(2026, 10, 7), 82.4));

        verify(pushService, never()).sendToUser(any(), any());
    }

    @Test
    void aLateSyncedWeighInOfAPastWeek_isHistoryNotNews() {
        listener.onWeightLogged(new WeightLoggedEvent(CLIENT_ID, MONDAY.minusDays(1), 82.4));

        verify(pushService, never()).sendToUser(any(), any());
    }

    @Test
    void theWeekIsTheClientsOwn_notTheServers() {
        // 23:30 UTC on Sunday is already Monday for a client at UTC+2: the week then is 12-18 October.
        listener = new ClientWeighInPushListener(userRepository, weightEntryRepository, trainerClientRepository,
                userSettingsRepository, pushService, Clock.fixed(Instant.parse("2026-10-11T23:30:00Z"), ZoneOffset.UTC));
        client.setUtcOffsetMinutes(120);
        when(weightEntryRepository.countByUserIdAndDeletedAtIsNullAndDateBetween(
                CLIENT_ID, LocalDate.of(2026, 10, 12), LocalDate.of(2026, 10, 18))).thenReturn(1L);

        listener.onWeightLogged(new WeightLoggedEvent(CLIENT_ID, LocalDate.of(2026, 10, 12), 82.4));

        verify(pushService).sendToUser(eq(9L), any());
    }

    @Test
    void everyActiveTrainerIsTold_unlessTheyTurnedItOff() {
        when(trainerClientRepository.findTrainerIdsByClientIdAndStatus(CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(9L, 10L));
        UserSettings off = new UserSettings();
        off.setClientWeighInPushEnabled(false);
        when(userSettingsRepository.findByUserId(10L)).thenReturn(Optional.of(off));

        listener.onWeightLogged(new WeightLoggedEvent(CLIENT_ID, LocalDate.of(2026, 10, 7), 82.4));

        verify(pushService).sendToUser(eq(9L), any());
        verify(pushService, never()).sendToUser(eq(10L), any());
    }

    @Test
    void theMessageIsInTheTrainersLanguage() {
        UserSettings hungarian = new UserSettings();
        hungarian.setLanguage(LanguagePreference.HUNGARIAN);
        when(userSettingsRepository.findByUserId(9L)).thenReturn(Optional.of(hungarian));

        listener.onWeightLogged(new WeightLoggedEvent(CLIENT_ID, LocalDate.of(2026, 10, 7), 82.4));

        ArgumentCaptor<PushMessage> message = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(9L), message.capture());
        assertThat(message.getValue().body()).isEqualTo("Anna leadta a heti mérést: 82,4 kg");
    }

    @Test
    void aFailureNeverEscapesTheListener() {
        when(userRepository.findById(CLIENT_ID)).thenThrow(new IllegalStateException("db down"));

        listener.onWeightLogged(new WeightLoggedEvent(CLIENT_ID, LocalDate.of(2026, 10, 7), 82.4));

        verify(pushService, never()).sendToUser(any(), any());
    }
}
