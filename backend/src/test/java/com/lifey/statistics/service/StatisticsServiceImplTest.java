package com.lifey.statistics.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.nutrition.meal.MealRepository;
import com.lifey.statistics.dto.StatisticsResponse;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.water.WaterEntryRepository;
import com.lifey.weight.WeightEntry;
import com.lifey.weight.WeightEntryRepository;
import com.lifey.workout.session.SessionKind;
import com.lifey.workout.session.WorkoutSessionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class StatisticsServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    MealRepository mealRepository;

    @Mock
    WorkoutSessionRepository workoutSessionRepository;

    @Mock
    WeightEntryRepository weightEntryRepository;

    @Mock
    WaterEntryRepository waterEntryRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @Mock
    UserRepository userRepository;

    @InjectMocks
    StatisticsServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        User user = new User();
        user.setId(USER_ID);
        user.setUtcOffsetMinutes(0);
        lenient().when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user));
    }

    @Test
    void daily_aggregatesFromStartOfToday() {
        stubAggregates(200.0, 20.0, 1L, 78.4);

        StatisticsResponse result = service.daily();

        assertThat(result.totalCalories()).isEqualTo(200.0);
        assertThat(result.totalProtein()).isEqualTo(20.0);
        assertThat(result.totalCarbs()).isEqualTo(30.0);
        assertThat(result.totalFat()).isEqualTo(10.0);
        assertThat(result.workoutCount()).isEqualTo(1);
        assertThat(result.latestWeight()).isEqualTo(78.4);
        assertThat(result.totalWater()).isEqualTo(1.5);
        assertThat(capturedFrom()).isEqualTo(LocalDate.now().atStartOfDay(ZoneOffset.UTC).toInstant());
    }

    @Test
    void weekly_aggregatesFromSevenDaysAgo() {
        stubAggregates(0.0, 0.0, 0L, null);

        service.weekly();

        assertThat(capturedFrom())
                .isEqualTo(LocalDate.now().minusDays(6).atStartOfDay(ZoneOffset.UTC).toInstant());
    }

    @Test
    void monthly_aggregatesFromThirtyDaysAgo() {
        stubAggregates(0.0, 0.0, 0L, null);

        service.monthly();

        assertThat(capturedFrom())
                .isEqualTo(LocalDate.now().minusDays(29).atStartOfDay(ZoneOffset.UTC).toInstant());
    }

    @Test
    void latestWeight_isNullWhenNoEntries() {
        stubAggregates(0.0, 0.0, 0L, null);

        assertThat(service.daily().latestWeight()).isNull();
    }

    /**
     * C3.1 kész-ha (docs/cardio/59-cardio-implementation-plan.md, D-C3.2): the
     * additive cardio fajta-bontás must not disturb any of the pre-existing
     * fields, on a dataset that actually has cardio in it (not just zeros).
     */
    @Test
    void cardioBreakdown_addsNewFieldsWithoutChangingOldOnes() {
        stubAggregates(200.0, 20.0, 5L, 78.4, 2L, 3720L, 12500.5, 340.0);

        StatisticsResponse result = service.daily();

        // Pre-C3.1 fields — bitre azonos, exactly as they'd have been without
        // the cardio breakdown ever existing.
        assertThat(result.totalCalories()).isEqualTo(200.0);
        assertThat(result.totalProtein()).isEqualTo(20.0);
        assertThat(result.totalCarbs()).isEqualTo(30.0);
        assertThat(result.totalFat()).isEqualTo(10.0);
        assertThat(result.workoutCount()).isEqualTo(5);
        assertThat(result.latestWeight()).isEqualTo(78.4);
        assertThat(result.totalWater()).isEqualTo(1.5);

        // New, additive fields.
        assertThat(result.cardioWorkoutCount()).isEqualTo(2);
        assertThat(result.strengthWorkoutCount()).isEqualTo(3); // workoutCount - cardioWorkoutCount
        assertThat(result.movingMinutes()).isEqualTo(62); // 3720s / 60, floor division
        assertThat(result.totalDistanceMeters()).isEqualTo(12500.5);
        assertThat(result.totalElevationGainMeters()).isEqualTo(340.0);
    }

    @Test
    void cardioBreakdown_isZeroForAPurelyStrengthHistory() {
        stubAggregates(200.0, 20.0, 4L, 78.4); // 4-arg overload defaults every cardio field to 0

        StatisticsResponse result = service.daily();

        assertThat(result.strengthWorkoutCount()).isEqualTo(4);
        assertThat(result.cardioWorkoutCount()).isZero();
        assertThat(result.movingMinutes()).isZero();
        assertThat(result.totalDistanceMeters()).isZero();
        assertThat(result.totalElevationGainMeters()).isZero();
    }

    private void stubAggregates(double calories, double protein, long workouts, Double weight) {
        stubAggregates(calories, protein, workouts, weight, 0L, 0L, 0.0, 0.0);
    }

    private void stubAggregates(double calories, double protein, long workouts, Double weight,
            long cardioWorkouts, long movingSeconds, double distanceMeters, double elevationMeters) {
        when(mealRepository.sumCaloriesSince(eq(USER_ID), any())).thenReturn(calories);
        when(mealRepository.sumProteinSince(eq(USER_ID), any())).thenReturn(protein);
        when(mealRepository.sumCarbsSince(eq(USER_ID), any())).thenReturn(30.0);
        when(mealRepository.sumFatSince(eq(USER_ID), any())).thenReturn(10.0);
        when(workoutSessionRepository.countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual(eq(USER_ID), any(Instant.class)))
                .thenReturn(workouts);
        lenient().when(workoutSessionRepository.countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndSessionKind(
                        eq(USER_ID), any(Instant.class), eq(SessionKind.CARDIO)))
                .thenReturn(cardioWorkouts);
        lenient().when(workoutSessionRepository.sumMovingSecondsSince(eq(USER_ID), any(Instant.class)))
                .thenReturn(movingSeconds);
        lenient().when(workoutSessionRepository.sumDistanceMetersSince(eq(USER_ID), any(Instant.class)))
                .thenReturn(distanceMeters);
        lenient().when(workoutSessionRepository.sumElevationGainMetersSince(eq(USER_ID), any(Instant.class)))
                .thenReturn(elevationMeters);
        if (weight == null) {
            when(weightEntryRepository.findFirstByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(USER_ID))
                    .thenReturn(Optional.empty());
        } else {
            WeightEntry e = new WeightEntry();
            e.setWeight(weight);
            when(weightEntryRepository.findFirstByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(USER_ID))
                    .thenReturn(Optional.of(e));
        }
        lenient().when(waterEntryRepository.sumVolumeLitersSince(eq(USER_ID), any(Instant.class)))
                .thenReturn(1.5);
    }

    private Instant capturedFrom() {
        ArgumentCaptor<Instant> captor = ArgumentCaptor.forClass(Instant.class);
        verify(mealRepository).sumCaloriesSince(eq(USER_ID), captor.capture());
        return captor.getValue();
    }
}
