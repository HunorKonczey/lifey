package com.lifey.statistics;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.nutrition.meal.MealRepository;
import com.lifey.statistics.dto.StatisticsResponse;
import com.lifey.water.WaterEntryRepository;
import com.lifey.weight.WeightEntry;
import com.lifey.weight.WeightEntryRepository;
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
import java.time.ZoneId;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

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

    @InjectMocks
    StatisticsServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
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
        assertThat(capturedFrom()).isEqualTo(LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant());
    }

    @Test
    void weekly_aggregatesFromSevenDaysAgo() {
        stubAggregates(0.0, 0.0, 0L, null);

        service.weekly();

        assertThat(capturedFrom())
                .isEqualTo(LocalDate.now().minusDays(6).atStartOfDay(ZoneId.systemDefault()).toInstant());
    }

    @Test
    void monthly_aggregatesFromThirtyDaysAgo() {
        stubAggregates(0.0, 0.0, 0L, null);

        service.monthly();

        assertThat(capturedFrom())
                .isEqualTo(LocalDate.now().minusDays(29).atStartOfDay(ZoneId.systemDefault()).toInstant());
    }

    @Test
    void latestWeight_isNullWhenNoEntries() {
        stubAggregates(0.0, 0.0, 0L, null);

        assertThat(service.daily().latestWeight()).isNull();
    }

    private void stubAggregates(double calories, double protein, long workouts, Double weight) {
        when(mealRepository.sumCaloriesSince(eq(USER_ID), any())).thenReturn(calories);
        when(mealRepository.sumProteinSince(eq(USER_ID), any())).thenReturn(protein);
        when(mealRepository.sumCarbsSince(eq(USER_ID), any())).thenReturn(30.0);
        when(mealRepository.sumFatSince(eq(USER_ID), any())).thenReturn(10.0);
        when(workoutSessionRepository.countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual(eq(USER_ID), any(Instant.class)))
                .thenReturn(workouts);
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
