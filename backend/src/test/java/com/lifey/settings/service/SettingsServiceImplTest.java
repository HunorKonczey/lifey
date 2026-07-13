package com.lifey.settings.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.settings.*;
import com.lifey.settings.dto.SettingsRequest;
import com.lifey.settings.dto.SettingsResponse;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SettingsServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    UserSettingsRepository repository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    SettingsServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void get_createsDefaultRowWithSystemLanguageWhenNoneExists() {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsResponse result = service.get();

        assertThat(result.language()).isEqualTo(LanguagePreference.SYSTEM);
        assertThat(result.theme()).isEqualTo(ThemePreference.SYSTEM);
    }

    @Test
    void update_withHungarianPersistsAndReturnsIt() {
        UserSettings existing = new UserSettings();
        existing.setUser(new User());
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsRequest request = new SettingsRequest(UnitSystem.METRIC, null, null, null, null, null, null,
                ThemePreference.SYSTEM, LanguagePreference.HUNGARIAN, true, true, true, true);

        SettingsResponse result = service.update(request);

        assertThat(result.language()).isEqualTo(LanguagePreference.HUNGARIAN);
    }

    @Test
    void update_withDailyStepGoalPersistsAndReturnsIt() {
        UserSettings existing = new UserSettings();
        existing.setUser(new User());
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsRequest request = new SettingsRequest(UnitSystem.METRIC, null, null, null, null, null, 10000,
                ThemePreference.SYSTEM, LanguagePreference.SYSTEM, true, true, true, true);

        SettingsResponse result = service.update(request);

        assertThat(result.dailyStepGoal()).isEqualTo(10000);
    }

    @Test
    void update_withNullDailyStepGoalPersistsAndReturnsNull() {
        UserSettings existing = new UserSettings();
        existing.setUser(new User());
        existing.setDailyStepGoal(10000);
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsRequest request = new SettingsRequest(UnitSystem.METRIC, null, null, null, null, null, null,
                ThemePreference.SYSTEM, LanguagePreference.SYSTEM, true, true, true, true);

        SettingsResponse result = service.update(request);

        assertThat(result.dailyStepGoal()).isNull();
    }

    @Test
    void get_createsDefaultRowWithWorkoutReminderEnabledWhenNoneExists() {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsResponse result = service.get();

        assertThat(result.workoutReminderEnabled()).isTrue();
    }

    @Test
    void update_canDisableWorkoutReminder() {
        UserSettings existing = new UserSettings();
        existing.setUser(new User());
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsRequest request = new SettingsRequest(UnitSystem.METRIC, null, null, null, null, null, null,
                ThemePreference.SYSTEM, LanguagePreference.SYSTEM, false, true, true, true);

        SettingsResponse result = service.update(request);

        assertThat(result.workoutReminderEnabled()).isFalse();
    }

    @Test
    void get_createsDefaultRowWithTrainerCommentPushEnabledWhenNoneExists() {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsResponse result = service.get();

        assertThat(result.trainerCommentPushEnabled()).isTrue();
    }

    @Test
    void update_canDisableTrainerCommentPush() {
        UserSettings existing = new UserSettings();
        existing.setUser(new User());
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsRequest request = new SettingsRequest(UnitSystem.METRIC, null, null, null, null, null, null,
                ThemePreference.SYSTEM, LanguagePreference.SYSTEM, true, false, true, true);

        SettingsResponse result = service.update(request);

        assertThat(result.trainerCommentPushEnabled()).isFalse();
    }

    @Test
    void get_createsDefaultRowWithTrainerGoalsPushEnabledWhenNoneExists() {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsResponse result = service.get();

        assertThat(result.trainerGoalsPushEnabled()).isTrue();
    }

    @Test
    void update_canDisableTrainerGoalsPush() {
        UserSettings existing = new UserSettings();
        existing.setUser(new User());
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsRequest request = new SettingsRequest(UnitSystem.METRIC, null, null, null, null, null, null,
                ThemePreference.SYSTEM, LanguagePreference.SYSTEM, true, true, false, true);

        SettingsResponse result = service.update(request);

        assertThat(result.trainerGoalsPushEnabled()).isFalse();
    }

    @Test
    void get_createsDefaultRowWithProgramAssignedPushEnabledWhenNoneExists() {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsResponse result = service.get();

        assertThat(result.programAssignedPushEnabled()).isTrue();
    }

    @Test
    void update_canDisableProgramAssignedPush() {
        UserSettings existing = new UserSettings();
        existing.setUser(new User());
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsRequest request = new SettingsRequest(UnitSystem.METRIC, null, null, null, null, null, null,
                ThemePreference.SYSTEM, LanguagePreference.SYSTEM, true, true, true, false);

        SettingsResponse result = service.update(request);

        assertThat(result.programAssignedPushEnabled()).isFalse();
    }

    @Test
    void isWeeklyReportEmailEnabled_createsDefaultRowAndReturnsTrueWhenNoneExists() {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        assertThat(service.isWeeklyReportEmailEnabled()).isTrue();
    }

    @Test
    void setWeeklyReportEmailEnabled_persistsAndReturnsNewValue() {
        UserSettings existing = new UserSettings();
        existing.setUser(new User());
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        boolean result = service.setWeeklyReportEmailEnabled(false);

        assertThat(result).isFalse();
        assertThat(existing.isWeeklyReportEmailEnabled()).isFalse();
    }

    @Test
    void updateNutritionGoalsForUser_createsRowWhenNoneExistsAndPersistsGoals() {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsResponse result = service.updateNutritionGoalsForUser(USER_ID, 2200, 150, 240, 70);

        assertThat(result.dailyCalorieGoal()).isEqualTo(2200);
        assertThat(result.dailyProteinGoal()).isEqualTo(150);
        assertThat(result.dailyCarbsGoal()).isEqualTo(240);
        assertThat(result.dailyFatGoal()).isEqualTo(70);
    }

    @Test
    void updateNutritionGoalsForUser_nullsClearExistingGoals() {
        UserSettings existing = new UserSettings();
        existing.setUser(new User());
        existing.setDailyCalorieGoal(2200);
        existing.setDailyProteinGoal(150);
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsResponse result = service.updateNutritionGoalsForUser(USER_ID, null, null, null, null);

        assertThat(result.dailyCalorieGoal()).isNull();
        assertThat(result.dailyProteinGoal()).isNull();
    }
}
