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
import com.lifey.trainer.dto.ClientNutritionGoalsRequest;
import com.lifey.trainer.dto.ClientNutritionGoalsResponse;
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
class ClientNutritionGoalsServiceImplTest {

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
    ClientNutritionGoalsServiceImpl service;

    private static SettingsResponse settings(Integer calories, Integer protein, Integer carbs, Integer fat) {
        return new SettingsResponse(UnitSystem.METRIC, calories, protein, carbs, fat, null, null,
                ThemePreference.SYSTEM, LanguagePreference.SYSTEM, true, true, true, true);
    }

    @Test
    void updateGoals_persistsAndReturnsGoals() {
        when(settingsService.forUser(CLIENT_ID)).thenReturn(settings(2000, 140, 200, 60));
        when(settingsService.updateNutritionGoalsForUser(CLIENT_ID, 2200, 150, 240, 70))
                .thenReturn(settings(2200, 150, 240, 70));
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());

        ClientNutritionGoalsResponse result = service.updateGoals(
                TRAINER_ID, CLIENT_ID, new ClientNutritionGoalsRequest(2200, 150, 240, 70));

        verify(trainerAccessService).requireActiveClient(TRAINER_ID, CLIENT_ID);
        assertThat(result.dailyCalorieGoal()).isEqualTo(2200);
        assertThat(result.dailyProteinGoal()).isEqualTo(150);
        assertThat(result.dailyCarbsGoal()).isEqualTo(240);
        assertThat(result.dailyFatGoal()).isEqualTo(70);
    }

    @Test
    void updateGoals_nullsClearGoals() {
        when(settingsService.forUser(CLIENT_ID)).thenReturn(settings(2200, 150, 240, 70));
        when(settingsService.updateNutritionGoalsForUser(CLIENT_ID, null, null, null, null))
                .thenReturn(settings(null, null, null, null));
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());

        ClientNutritionGoalsResponse result = service.updateGoals(
                TRAINER_ID, CLIENT_ID, new ClientNutritionGoalsRequest(null, null, null, null));

        assertThat(result.dailyCalorieGoal()).isNull();
        assertThat(result.dailyProteinGoal()).isNull();
        assertThat(result.dailyCarbsGoal()).isNull();
        assertThat(result.dailyFatGoal()).isNull();
    }

    @Test
    void updateGoals_notYourClientPropagatesAndNeverTouchesSettings() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID))
                .thenThrow(new NotYourClientException("nope"));
        ClientNutritionGoalsRequest request = new ClientNutritionGoalsRequest(2200, 150, 240, 70);

        assertThatThrownBy(() -> service.updateGoals(TRAINER_ID, CLIENT_ID, request))
                .isInstanceOf(NotYourClientException.class);

        verify(settingsService, never()).updateNutritionGoalsForUser(any(), any(), any(), any(), any());
        verify(pushService, never()).sendToUser(any(), any());
    }

    @Test
    void updateGoals_realChangeSendsPushWithSummary() {
        when(settingsService.forUser(CLIENT_ID)).thenReturn(settings(2000, 140, 200, 60));
        when(settingsService.updateNutritionGoalsForUser(CLIENT_ID, 2200, 150, 240, 70))
                .thenReturn(settings(2200, 150, 240, 70));
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());

        service.updateGoals(TRAINER_ID, CLIENT_ID, new ClientNutritionGoalsRequest(2200, 150, 240, 70));

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(CLIENT_ID), captor.capture());
        PushMessage message = captor.getValue();
        assertThat(message.title()).isEqualTo("Your trainer updated your nutrition goals");
        assertThat(message.body()).isEqualTo("2200 kcal · protein 150 g · carbs 240 g · fat 70 g");
        assertThat(message.data()).containsEntry("type", "nutrition_goals");
    }

    @Test
    void updateGoals_identicalValuesDoNotSendPush() {
        when(settingsService.forUser(CLIENT_ID)).thenReturn(settings(2200, 150, 240, 70));
        when(settingsService.updateNutritionGoalsForUser(CLIENT_ID, 2200, 150, 240, 70))
                .thenReturn(settings(2200, 150, 240, 70));

        service.updateGoals(TRAINER_ID, CLIENT_ID, new ClientNutritionGoalsRequest(2200, 150, 240, 70));

        verify(pushService, never()).sendToUser(any(), any());
    }

    @Test
    void updateGoals_clearingAllGoalsSendsClearedPush() {
        when(settingsService.forUser(CLIENT_ID)).thenReturn(settings(2200, 150, 240, 70));
        when(settingsService.updateNutritionGoalsForUser(CLIENT_ID, null, null, null, null))
                .thenReturn(settings(null, null, null, null));
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());

        service.updateGoals(TRAINER_ID, CLIENT_ID, new ClientNutritionGoalsRequest(null, null, null, null));

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(CLIENT_ID), captor.capture());
        assertThat(captor.getValue().body()).isEqualTo("Goals cleared");
    }

    @Test
    void updateGoals_skipsPushWhenTrainerGoalsPushDisabled() {
        when(settingsService.forUser(CLIENT_ID)).thenReturn(settings(2000, 140, 200, 60));
        when(settingsService.updateNutritionGoalsForUser(CLIENT_ID, 2200, 150, 240, 70))
                .thenReturn(settings(2200, 150, 240, 70));
        UserSettings settingsRow = new UserSettings();
        settingsRow.setTrainerGoalsPushEnabled(false);
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.of(settingsRow));

        service.updateGoals(TRAINER_ID, CLIENT_ID, new ClientNutritionGoalsRequest(2200, 150, 240, 70));

        verify(pushService, never()).sendToUser(any(), any());
    }

    @Test
    void updateGoals_sendsPushWithHungarianCopyWhenClientPrefersHungarian() {
        when(settingsService.forUser(CLIENT_ID)).thenReturn(settings(2000, 140, 200, 60));
        when(settingsService.updateNutritionGoalsForUser(CLIENT_ID, 2200, 150, 240, 70))
                .thenReturn(settings(2200, 150, 240, 70));
        UserSettings settingsRow = new UserSettings();
        settingsRow.setLanguage(LanguagePreference.HUNGARIAN);
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.of(settingsRow));

        service.updateGoals(TRAINER_ID, CLIENT_ID, new ClientNutritionGoalsRequest(2200, 150, 240, 70));

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(CLIENT_ID), captor.capture());
        assertThat(captor.getValue().title()).isEqualTo("Az edződ frissítette a táplálkozási céljaidat");
    }
}
