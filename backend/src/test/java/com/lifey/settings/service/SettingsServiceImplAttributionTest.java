package com.lifey.settings.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.settings.GoalsSource;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.NutritionGoalsAttribution;
import com.lifey.settings.ThemePreference;
import com.lifey.settings.UnitSystem;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.settings.dto.NutritionGoalsSourceResponse;
import com.lifey.settings.dto.SettingsRequest;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.userdetails.dto.SuggestGoalsResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

/** docs/redesign-web/82 section 2.4: who set the nutrition goals, and the rule that keeps that fact from being overwritten. */
@ExtendWith(MockitoExtension.class)
class SettingsServiceImplAttributionTest {

    private static final Long CLIENT_ID = 1L;
    private static final Long TRAINER_ID = 9L;
    private static final Instant TRAINER_SET_AT = Instant.parse("2026-09-12T08:00:00Z");

    @Mock
    UserSettingsRepository repository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    SettingsServiceImpl service;

    @BeforeEach
    void currentUserIsTheClient() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(CLIENT_ID);
        lenient().when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    }

    /** A client whose goals a trainer set on 12 September. */
    private UserSettings goalsSetByTheTrainer() {
        UserSettings settings = new UserSettings();
        settings.setUser(new User());
        settings.setDailyCalorieGoal(2200);
        settings.setDailyProteinGoal(150);
        settings.setDailyCarbsGoal(240);
        settings.setDailyFatGoal(70);
        settings.setNutritionGoalsSetBy(TRAINER_ID);
        settings.setNutritionGoalsSetAt(TRAINER_SET_AT);
        when(repository.findByUserId(CLIENT_ID)).thenReturn(Optional.of(settings));
        return settings;
    }

    private static SettingsRequest request(Integer calories, Integer protein, Integer carbs, Integer fat, ThemePreference theme) {
        return new SettingsRequest(UnitSystem.METRIC, calories, protein, carbs, fat, null, null,
                theme, LanguagePreference.SYSTEM, true, true, true, true, true, null, null, null, true, 90);
    }

    // --- the trainer's path -------------------------------------------------------------------------------

    @Test
    void aTrainerChangeRecordsTheTrainerAndTheMoment() {
        UserSettings settings = new UserSettings();
        settings.setUser(new User());
        settings.setDailyCalorieGoal(1800);
        when(repository.findByUserId(CLIENT_ID)).thenReturn(Optional.of(settings));

        service.updateNutritionGoalsForUser(CLIENT_ID, TRAINER_ID, 2200, 150, 240, 70);

        assertThat(settings.getNutritionGoalsSetBy()).isEqualTo(TRAINER_ID);
        assertThat(settings.getNutritionGoalsSetAt()).isNotNull();
    }

    @Test
    void aTrainerSavingIdenticalGoalsDoesNotMoveTheStamp() {
        UserSettings settings = goalsSetByTheTrainer();

        service.updateNutritionGoalsForUser(CLIENT_ID, 77L, 2200, 150, 240, 70);

        assertThat(settings.getNutritionGoalsSetBy()).as("still the original trainer").isEqualTo(TRAINER_ID);
        assertThat(settings.getNutritionGoalsSetAt()).isEqualTo(TRAINER_SET_AT);
    }

    // --- the client's path: the silent-failure case --------------------------------------------------------

    @Test
    void anUnrelatedSettingsSyncWithUnchangedGoalsNeverOverwritesSetByYourTrainer() {
        UserSettings settings = goalsSetByTheTrainer();

        // The mobile app re-sends the whole object with the same goals; only the theme changed.
        service.update(request(2200, 150, 240, 70, ThemePreference.DARK));

        assertThat(settings.getTheme()).isEqualTo(ThemePreference.DARK);
        assertThat(settings.getNutritionGoalsSetBy()).isEqualTo(TRAINER_ID);
        assertThat(settings.getNutritionGoalsSetAt()).isEqualTo(TRAINER_SET_AT);
    }

    @Test
    void theClientChangingAGoalTakesOverTheAttribution() {
        UserSettings settings = goalsSetByTheTrainer();

        service.update(request(2400, 150, 240, 70, ThemePreference.SYSTEM));

        assertThat(settings.getNutritionGoalsSetBy()).isEqualTo(CLIENT_ID);
        assertThat(settings.getNutritionGoalsSetAt()).isAfter(TRAINER_SET_AT);
    }

    @Test
    void clearingAGoalCountsAsAChange() {
        UserSettings settings = goalsSetByTheTrainer();

        service.update(request(2200, 150, 240, null, ThemePreference.SYSTEM));

        assertThat(settings.getNutritionGoalsSetBy()).isEqualTo(CLIENT_ID);
    }

    @Test
    void changingOnlyTheWaterGoalIsNotANutritionGoalChange() {
        UserSettings settings = goalsSetByTheTrainer();
        SettingsRequest waterOnly = new SettingsRequest(UnitSystem.METRIC, 2200, 150, 240, 70, 3.0, null,
                ThemePreference.SYSTEM, LanguagePreference.SYSTEM, true, true, true, true, true, null, null, null, true, 90);

        service.update(waterOnly);

        assertThat(settings.getDailyWaterGoalLiters()).isEqualTo(3.0);
        assertThat(settings.getNutritionGoalsSetBy()).isEqualTo(TRAINER_ID);
    }

    @Test
    void recalculatedSuggestedGoalsAreAttributedToTheUserOnlyWhenTheyDiffer() {
        UserSettings settings = goalsSetByTheTrainer();

        service.applyGoals(new SuggestGoalsResponse(1800, 2500, 2200, 150, 240, 70, 2.5));
        assertThat(settings.getNutritionGoalsSetBy()).as("same values, same attribution").isEqualTo(TRAINER_ID);

        service.applyGoals(new SuggestGoalsResponse(1800, 2500, 2000, 140, 220, 65, 2.5));
        assertThat(settings.getNutritionGoalsSetBy()).isEqualTo(CLIENT_ID);
    }

    // --- reading it back ----------------------------------------------------------------------------------

    @Test
    void noSettingsRowOrNoStampMeansUnknown_andInventsNoDate() {
        when(repository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());
        assertThat(service.nutritionGoalsAttribution(CLIENT_ID)).isEqualTo(NutritionGoalsAttribution.unknown());

        UserSettings legacy = new UserSettings();
        legacy.setUser(new User());
        legacy.setDailyCalorieGoal(2000);
        when(repository.findByUserId(2L)).thenReturn(Optional.of(legacy));
        NutritionGoalsAttribution attribution = service.nutritionGoalsAttribution(2L);
        assertThat(attribution.source()).isEqualTo(GoalsSource.UNKNOWN);
        assertThat(attribution.setAt()).isNull();
    }

    @Test
    void attributionFactoryTellsSelfFromTrainerFromADeletedTrainer() {
        assertThat(NutritionGoalsAttribution.of(1L, TRAINER_SET_AT, 1L).source()).isEqualTo(GoalsSource.SELF);
        assertThat(NutritionGoalsAttribution.of(1L, TRAINER_SET_AT, 9L).source()).isEqualTo(GoalsSource.TRAINER);
        // set_by became null when the trainer's account was deleted; the date survives.
        NutritionGoalsAttribution deleted = NutritionGoalsAttribution.of(1L, TRAINER_SET_AT, null);
        assertThat(deleted.source()).isEqualTo(GoalsSource.TRAINER);
        assertThat(deleted.setAt()).isEqualTo(TRAINER_SET_AT);
        assertThat(NutritionGoalsAttribution.of(1L, null, 9L).source()).as("no date, no claim").isEqualTo(GoalsSource.UNKNOWN);
    }

    @Test
    void theClientSourceNamesTheTrainer_orFallsBackToTheEmail() {
        goalsSetByTheTrainer();
        User trainer = new User();
        trainer.setFirstName("Bence");
        trainer.setLastName("Edző");
        trainer.setEmail("bence@example.com");
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.of(trainer));

        NutritionGoalsSourceResponse named = service.nutritionGoalsSource();
        assertThat(named.source()).isEqualTo(GoalsSource.TRAINER);
        assertThat(named.setAt()).isEqualTo(TRAINER_SET_AT);
        assertThat(named.setByName()).isEqualTo("Bence Edző");

        trainer.setFirstName(null);
        trainer.setLastName(null);
        assertThat(service.nutritionGoalsSource().setByName()).isEqualTo("bence@example.com");
    }

    @Test
    void aSelfSetSourceCarriesNoName_andADeletedTrainerNone_eitherWayTheDateStays() {
        UserSettings settings = goalsSetByTheTrainer();
        settings.setNutritionGoalsSetBy(CLIENT_ID);
        NutritionGoalsSourceResponse self = service.nutritionGoalsSource();
        assertThat(self.source()).isEqualTo(GoalsSource.SELF);
        assertThat(self.setByName()).isNull();

        settings.setNutritionGoalsSetBy(null);
        NutritionGoalsSourceResponse gone = service.nutritionGoalsSource();
        assertThat(gone.source()).isEqualTo(GoalsSource.TRAINER);
        assertThat(gone.setByName()).isNull();
        assertThat(gone.setAt()).isEqualTo(TRAINER_SET_AT);
    }
}
