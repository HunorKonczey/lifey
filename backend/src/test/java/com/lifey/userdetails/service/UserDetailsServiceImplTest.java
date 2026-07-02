package com.lifey.userdetails.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.userdetails.ActivityLevel;
import com.lifey.userdetails.Gender;
import com.lifey.userdetails.PrimaryGoal;
import com.lifey.userdetails.UserDetails;
import com.lifey.userdetails.UserDetailsRepository;
import com.lifey.userdetails.dto.SuggestGoalsRequest;
import com.lifey.userdetails.dto.SuggestGoalsResponse;
import com.lifey.userdetails.dto.UserDetailsRequest;
import com.lifey.userdetails.dto.UserDetailsResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.lenient;
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
