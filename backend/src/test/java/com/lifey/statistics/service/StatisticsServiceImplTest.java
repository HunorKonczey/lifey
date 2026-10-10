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
        assertThat(capturedFrom()).isEqualTo(LocalDate.now(ZoneOffset.UTC).atStartOfDay(ZoneOffset.UTC).toInstant());
    }

    @Test
    void daily_withoutADate_anchorsOnTheUsersOwnToday_notTheServers() {
        // UTC+14: from 10:00 UTC the user's calendar day is one ahead of the server's.
        User user = new User();
        user.setId(USER_ID);
        user.setUtcOffsetMinutes(14 * 60);
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user));
        stubAggregates(0.0, 0.0, 0L, null);

        service.daily();

        ZoneOffset zone = ZoneOffset.ofHours(14);
        assertThat(capturedFrom()).isEqualTo(LocalDate.now(zone).atStartOfDay(zone).toInstant());
    }

    @Test
    void weekly_aggregatesFromSevenDaysAgo() {
        stubAggregates(0.0, 0.0, 0L, null);

        service.weekly();

        assertThat(capturedFrom())
                .isEqualTo(LocalDate.now(ZoneOffset.UTC).minusDays(6).atStartOfDay(ZoneOffset.UTC).toInstant());
    }

    @Test
    void monthly_aggregatesFromThirtyDaysAgo() {
        stubAggregates(0.0, 0.0, 0L, null);

        service.monthly();

        assertThat(capturedFrom())
                .isEqualTo(LocalDate.now(ZoneOffset.UTC).minusDays(29).atStartOfDay(ZoneOffset.UTC).toInstant());
    }

    @Test
    void aPastDate_endsItsPeriodAfterThatDay_insteadOfRunningOnToTheEndOfTime() {
        stubAggregates(0.0, 0.0, 0L, null);
        LocalDate day = LocalDate.of(2026, 3, 10);

        service.daily(day);

        assertThat(capturedFrom()).isEqualTo(day.atStartOfDay(ZoneOffset.UTC).toInstant());
        assertThat(capturedToExclusive()).isEqualTo(day.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant());
    }

    @Test
    void weeklyAndMonthly_endAfterTheGivenDay() {
        stubAggregates(0.0, 0.0, 0L, null);
        LocalDate day = LocalDate.of(2026, 3, 10);

        service.weekly(day);

        assertThat(capturedFrom()).isEqualTo(day.minusDays(6).atStartOfDay(ZoneOffset.UTC).toInstant());
        assertThat(capturedToExclusive()).isEqualTo(day.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant());
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

    @Test
    void daily_carriesTheKnownFibreAndSugar_andFlagsAPartialSum() {
        stubAggregates(200.0, 20.0, 0L, null);
        when(mealRepository.sumFiberBetween(eq(USER_ID), any(), any())).thenReturn(12.5);
        when(mealRepository.sumSugarBetween(eq(USER_ID), any(), any())).thenReturn(30.0);
        when(mealRepository.countEntriesMissingFiberOrSugarBetween(eq(USER_ID), any(), any())).thenReturn(2L);

        StatisticsResponse result = service.daily();

        assertThat(result.totalFiber()).isEqualTo(12.5);
        assertThat(result.totalSugar()).isEqualTo(30.0);
        assertThat(result.fiberSugarPartial()).isTrue();
    }

    @Test
    void daily_withNoFigureAnywhere_hasNullFibreAndSugar_andIsNotPartial() {
        stubAggregates(200.0, 20.0, 0L, null);
        when(mealRepository.sumFiberBetween(eq(USER_ID), any(), any())).thenReturn(null);
        when(mealRepository.sumSugarBetween(eq(USER_ID), any(), any())).thenReturn(null);
        lenient().when(mealRepository.countEntriesMissingFiberOrSugarBetween(eq(USER_ID), any(), any())).thenReturn(5L);

        StatisticsResponse result = service.daily();

        assertThat(result.totalFiber()).isNull();
        assertThat(result.totalSugar()).isNull();
        assertThat(result.fiberSugarPartial()).isFalse();
    }

    @Test
    void daily_whenEveryEntryHasAFigure_isNotPartial() {
        stubAggregates(200.0, 20.0, 0L, null);
        when(mealRepository.sumFiberBetween(eq(USER_ID), any(), any())).thenReturn(3.0);
        when(mealRepository.sumSugarBetween(eq(USER_ID), any(), any())).thenReturn(4.0);
        when(mealRepository.countEntriesMissingFiberOrSugarBetween(eq(USER_ID), any(), any())).thenReturn(0L);

        assertThat(service.daily().fiberSugarPartial()).isFalse();
    }

    private void stubAggregates(double calories, double protein, long workouts, Double weight) {
        stubAggregates(calories, protein, workouts, weight, 0L, 0L, 0.0, 0.0);
    }

    private void stubAggregates(double calories, double protein, long workouts, Double weight,
            long cardioWorkouts, long movingSeconds, double distanceMeters, double elevationMeters) {
        when(mealRepository.sumCaloriesBetween(eq(USER_ID), any(), any())).thenReturn(calories);
        when(mealRepository.sumProteinBetween(eq(USER_ID), any(), any())).thenReturn(protein);
        when(mealRepository.sumCarbsBetween(eq(USER_ID), any(), any())).thenReturn(30.0);
        when(mealRepository.sumFatBetween(eq(USER_ID), any(), any())).thenReturn(10.0);
        when(workoutSessionRepository.countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                eq(USER_ID), any(Instant.class), any(Instant.class)))
                .thenReturn(workouts);
        lenient().when(workoutSessionRepository.countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThanAndSessionKind(
                        eq(USER_ID), any(Instant.class), any(Instant.class), eq(SessionKind.CARDIO)))
                .thenReturn(cardioWorkouts);
        lenient().when(workoutSessionRepository.sumMovingSecondsBetween(eq(USER_ID), any(Instant.class), any(Instant.class)))
                .thenReturn(movingSeconds);
        lenient().when(workoutSessionRepository.sumDistanceMetersBetween(eq(USER_ID), any(Instant.class), any(Instant.class)))
                .thenReturn(distanceMeters);
        lenient().when(workoutSessionRepository.sumElevationGainMetersBetween(eq(USER_ID), any(Instant.class), any(Instant.class)))
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
        lenient().when(waterEntryRepository.sumVolumeLitersBetween(eq(USER_ID), any(Instant.class), any(Instant.class)))
                .thenReturn(1.5);
    }

    private Instant capturedFrom() {
        ArgumentCaptor<Instant> captor = ArgumentCaptor.forClass(Instant.class);
        verify(mealRepository).sumCaloriesBetween(eq(USER_ID), captor.capture(), any());
        return captor.getValue();
    }

    private Instant capturedToExclusive() {
        ArgumentCaptor<Instant> captor = ArgumentCaptor.forClass(Instant.class);
        verify(mealRepository).sumCaloriesBetween(eq(USER_ID), any(), captor.capture());
        return captor.getValue();
    }
}
