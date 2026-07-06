package com.lifey.userdetails.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.settings.service.SettingsService;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.userdetails.ActivityLevel;
import com.lifey.userdetails.Gender;
import com.lifey.userdetails.PrimaryGoal;
import com.lifey.userdetails.UserDetails;
import com.lifey.userdetails.UserDetailsField;
import com.lifey.userdetails.UserDetailsRepository;
import com.lifey.userdetails.dto.SuggestGoalsRequest;
import com.lifey.userdetails.dto.SuggestGoalsResponse;
import com.lifey.userdetails.dto.UserDetailsPatchRequest;
import com.lifey.userdetails.dto.UserDetailsRequest;
import com.lifey.userdetails.dto.UserDetailsResponse;
import com.lifey.weight.WeightEntry;
import com.lifey.weight.WeightEntryRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserDetailsServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    UserDetailsRepository repository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @Mock
    WeightEntryRepository weightEntryRepository;

    @Mock
    SettingsService settingsService;

    @InjectMocks
    UserDetailsServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void get_throwsNotFoundWhenUserHasNoRow() {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.get())
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void get_returnsExistingRow() {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(entity()));

        UserDetailsResponse result = service.get();

        assertThat(result.gender()).isEqualTo(Gender.MALE);
        assertThat(result.heightCm()).isEqualTo(180.0);
    }

    @Test
    void upsert_createsNewRowWhenAbsent() {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.empty());
        ArgumentCaptor<UserDetails> captor = ArgumentCaptor.forClass(UserDetails.class);
        when(repository.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));

        UserDetailsRequest request = new UserDetailsRequest(
                Gender.FEMALE, LocalDate.of(1995, 5, 1), 165.0, ActivityLevel.LIGHT, PrimaryGoal.MAINTAIN, null);

        UserDetailsResponse result = service.upsert(request);

        assertThat(captor.getValue().getUser()).isNotNull();
        assertThat(result.gender()).isEqualTo(Gender.FEMALE);
        assertThat(result.heightCm()).isEqualTo(165.0);
    }

    @Test
    void upsert_updatesExistingRowInPlace_noSecondRowCreated() {
        UserDetails existing = entity();
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(existing)).thenReturn(existing);

        UserDetailsRequest request = new UserDetailsRequest(
                Gender.FEMALE, LocalDate.of(1990, 1, 1), 170.0, ActivityLevel.ACTIVE, PrimaryGoal.GAIN_MUSCLE, 65.0);

        UserDetailsResponse result = service.upsert(request);

        assertThat(result.gender()).isEqualTo(Gender.FEMALE);
        assertThat(result.heightCm()).isEqualTo(170.0);
        assertThat(result.targetWeightKg()).isEqualTo(65.0);
    }

    @Test
    void partialUpdate_throwsNotFoundWhenUserHasNoRow() {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.empty());

        UserDetailsPatchRequest request = new UserDetailsPatchRequest(
                Set.of(UserDetailsField.HEIGHT_CM), Gender.MALE, LocalDate.of(1990, 1, 1), 182.0,
                ActivityLevel.MODERATE, PrimaryGoal.MAINTAIN, null);

        assertThatThrownBy(() -> service.partialUpdate(request))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void partialUpdate_onlyAppliesSelectedFields() {
        UserDetails existing = entity();
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(existing)).thenReturn(existing);
        when(weightEntryRepository.findFirstByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(USER_ID))
                .thenReturn(Optional.empty());

        // Only HEIGHT_CM is selected — gender/activityLevel/primaryGoal in the
        // payload must be ignored even though they differ from the existing row.
        UserDetailsPatchRequest request = new UserDetailsPatchRequest(
                Set.of(UserDetailsField.HEIGHT_CM), Gender.FEMALE, LocalDate.of(1990, 1, 1), 182.0,
                ActivityLevel.ACTIVE, PrimaryGoal.GAIN_MUSCLE, null);

        UserDetailsResponse result = service.partialUpdate(request);

        assertThat(result.heightCm()).isEqualTo(182.0);
        assertThat(result.gender()).isEqualTo(Gender.MALE);
        assertThat(result.activityLevel()).isEqualTo(ActivityLevel.MODERATE);
        assertThat(result.primaryGoal()).isEqualTo(PrimaryGoal.MAINTAIN);
    }

    @Test
    void partialUpdate_skipsGoalRecalcWhenNoWeightEntry() {
        UserDetails existing = entity();
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(existing)).thenReturn(existing);
        when(weightEntryRepository.findFirstByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(USER_ID))
                .thenReturn(Optional.empty());

        UserDetailsPatchRequest request = new UserDetailsPatchRequest(
                Set.of(UserDetailsField.HEIGHT_CM), Gender.MALE, LocalDate.of(1990, 1, 1), 182.0,
                ActivityLevel.MODERATE, PrimaryGoal.MAINTAIN, null);

        service.partialUpdate(request);

        verify(settingsService, never()).applyGoals(any());
    }

    @Test
    void partialUpdate_recalculatesAndAppliesGoalsWhenWeightEntryExists() {
        UserDetails existing = entity();
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(existing)).thenReturn(existing);

        WeightEntry weightEntry = new WeightEntry();
        weightEntry.setWeight(80.0);
        when(weightEntryRepository.findFirstByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(USER_ID))
                .thenReturn(Optional.of(weightEntry));

        UserDetailsPatchRequest request = new UserDetailsPatchRequest(
                Set.of(UserDetailsField.HEIGHT_CM), Gender.MALE, LocalDate.of(1990, 1, 1), 182.0,
                ActivityLevel.MODERATE, PrimaryGoal.MAINTAIN, null);

        service.partialUpdate(request);

        ArgumentCaptor<SuggestGoalsResponse> captor = ArgumentCaptor.forClass(SuggestGoalsResponse.class);
        verify(settingsService).applyGoals(captor.capture());
        assertThat(captor.getValue().calories()).isPositive();
    }

    @Test
    void suggestGoals_delegatesToCalculator() {
        SuggestGoalsRequest request = new SuggestGoalsRequest(
                Gender.MALE, LocalDate.now().minusYears(30), 180.0, 80.0, ActivityLevel.MODERATE, PrimaryGoal.LOSE_WEIGHT);

        SuggestGoalsResponse result = service.suggestGoals(request);

        assertThat(result.calories()).isPositive();
        assertThat(result.proteinGrams()).isPositive();
        assertThat(result.waterLiters()).isPositive();
    }

    private static UserDetails entity() {
        UserDetails e = new UserDetails();
        e.setId(1L);
        e.setGender(Gender.MALE);
        e.setBirthDate(LocalDate.of(1990, 1, 1));
        e.setHeightCm(180.0);
        e.setActivityLevel(ActivityLevel.MODERATE);
        e.setPrimaryGoal(PrimaryGoal.MAINTAIN);
        return e;
    }
}
