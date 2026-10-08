package com.lifey.trainer.service;

import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.ThemePreference;
import com.lifey.settings.UnitSystem;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.settings.dto.SettingsResponse;
import com.lifey.settings.service.SettingsService;
import com.lifey.trainer.dto.ClientStepGoalRequest;
import com.lifey.trainer.dto.ClientStepGoalResponse;
import com.lifey.trainer.exception.NotYourClientException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ClientStepGoalServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;

    @Mock
    TrainerAccessService trainerAccessService;

    @Mock
    SettingsService settingsService;

    @Mock
    UserSettingsRepository userSettingsRepository;

    @Mock
    PushService pushService;

    @InjectMocks
    ClientStepGoalServiceImpl service;

    private static SettingsResponse settings(Integer stepGoal) {
        return new SettingsResponse(UnitSystem.METRIC, null, null, null, null, null, stepGoal,
                ThemePreference.SYSTEM, LanguagePreference.SYSTEM, true, true, true, true, true, null, null, true, 90);
    }

    private static UserSettings clientSettings(LanguagePreference language, boolean trainerGoalsPush) {
        UserSettings s = new UserSettings();
        s.setLanguage(language);
        s.setTrainerGoalsPushEnabled(trainerGoalsPush);
        return s;
    }

    @Test
    void updateStepGoal_setsTheGoalAndPushesTheClientOnce() {
        when(settingsService.forUser(CLIENT_ID)).thenReturn(settings(8000));
        when(settingsService.updateStepGoalForUser(CLIENT_ID, 10000)).thenReturn(settings(10000));
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());

        ClientStepGoalResponse result = service.updateStepGoal(TRAINER_ID, CLIENT_ID, new ClientStepGoalRequest(10000));

        verify(trainerAccessService).requireActiveClient(TRAINER_ID, CLIENT_ID);
        assertThat(result.dailyStepGoal()).isEqualTo(10000);
        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(CLIENT_ID), captor.capture());
        assertThat(captor.getValue().title()).isEqualTo("Your trainer updated your step goal");
        assertThat(captor.getValue().body()).isEqualTo("10000 steps a day");
        assertThat(captor.getValue().data()).containsEntry("type", "step_goal");
    }

    @Test
    void updateStepGoal_speaksHungarianToAHungarianClient() {
        when(settingsService.forUser(CLIENT_ID)).thenReturn(settings(null));
        when(settingsService.updateStepGoalForUser(CLIENT_ID, 9000)).thenReturn(settings(9000));
        when(userSettingsRepository.findByUserId(CLIENT_ID))
                .thenReturn(Optional.of(clientSettings(LanguagePreference.HUNGARIAN, true)));

        service.updateStepGoal(TRAINER_ID, CLIENT_ID, new ClientStepGoalRequest(9000));

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(CLIENT_ID), captor.capture());
        assertThat(captor.getValue().title()).isEqualTo("Az edződ frissítette a lépéscélodat");
        assertThat(captor.getValue().body()).isEqualTo("9000 lépés naponta");
    }

    @Test
    void updateStepGoal_aNullGoalClearsItAndSaysSo() {
        when(settingsService.forUser(CLIENT_ID)).thenReturn(settings(8000));
        when(settingsService.updateStepGoalForUser(CLIENT_ID, null)).thenReturn(settings(null));
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());

        ClientStepGoalResponse result = service.updateStepGoal(TRAINER_ID, CLIENT_ID, new ClientStepGoalRequest(null));

        assertThat(result.dailyStepGoal()).isNull();
        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(CLIENT_ID), captor.capture());
        assertThat(captor.getValue().body()).isEqualTo("Step goal cleared");
    }

    @Test
    void updateStepGoal_theSameValueSendsNoPush() {
        when(settingsService.forUser(CLIENT_ID)).thenReturn(settings(8000));
        when(settingsService.updateStepGoalForUser(CLIENT_ID, 8000)).thenReturn(settings(8000));

        service.updateStepGoal(TRAINER_ID, CLIENT_ID, new ClientStepGoalRequest(8000));

        verify(pushService, never()).sendToUser(any(), any());
    }

    @Test
    void updateStepGoal_aClientWhoTurnedTrainerGoalPushesOffIsNotNotified() {
        when(settingsService.forUser(CLIENT_ID)).thenReturn(settings(8000));
        when(settingsService.updateStepGoalForUser(CLIENT_ID, 12000)).thenReturn(settings(12000));
        when(userSettingsRepository.findByUserId(CLIENT_ID))
                .thenReturn(Optional.of(clientSettings(LanguagePreference.SYSTEM, false)));

        service.updateStepGoal(TRAINER_ID, CLIENT_ID, new ClientStepGoalRequest(12000));

        verify(pushService, never()).sendToUser(any(), any());
    }

    @Test
    void updateStepGoal_notYourClientPropagatesAndTouchesNothing() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID))
                .thenThrow(new NotYourClientException("nope"));
        ClientStepGoalRequest request = new ClientStepGoalRequest(10000);

        assertThatThrownBy(() -> service.updateStepGoal(TRAINER_ID, CLIENT_ID, request))
                .isInstanceOf(NotYourClientException.class);

        verify(settingsService, never()).updateStepGoalForUser(any(), any());
        verify(pushService, never()).sendToUser(any(), any());
    }
}
