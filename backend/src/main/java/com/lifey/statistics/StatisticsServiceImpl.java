package com.lifey.statistics;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.nutrition.meal.MealRepository;
import com.lifey.statistics.dto.StatisticsResponse;
import com.lifey.water.WaterEntryRepository;
import com.lifey.weight.WeightEntry;
import com.lifey.weight.WeightEntryRepository;
import com.lifey.workout.session.WorkoutSessionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;

/**
 * Aggregates nutrition, workout and weight data over rolling periods ending now,
 * scoped to the current user.
 */
@Service
@Transactional(readOnly = true)
public class StatisticsServiceImpl implements StatisticsService {

    private final MealRepository mealRepository;
    private final WorkoutSessionRepository workoutSessionRepository;
    private final WeightEntryRepository weightEntryRepository;
    private final WaterEntryRepository waterEntryRepository;
    private final CurrentUserProvider currentUserProvider;

    public StatisticsServiceImpl(MealRepository mealRepository,
                                 WorkoutSessionRepository workoutSessionRepository,
                                 WeightEntryRepository weightEntryRepository,
                                 WaterEntryRepository waterEntryRepository,
                                 CurrentUserProvider currentUserProvider) {
        this.mealRepository = mealRepository;
        this.workoutSessionRepository = workoutSessionRepository;
        this.weightEntryRepository = weightEntryRepository;
        this.waterEntryRepository = waterEntryRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Override
    public StatisticsResponse daily() {
        return daily(LocalDate.now());
    }

    @Override
    public StatisticsResponse daily(LocalDate today) {
        return forPeriodSince(today);
    }

    @Override
    public StatisticsResponse weekly() {
        return weekly(LocalDate.now());
    }

    @Override
    public StatisticsResponse weekly(LocalDate today) {
        return forPeriodSince(today.minusDays(6));
    }

    @Override
    public StatisticsResponse monthly() {
        return monthly(LocalDate.now());
    }

    @Override
    public StatisticsResponse monthly(LocalDate today) {
        return forPeriodSince(today.minusDays(29));
    }

    private StatisticsResponse forPeriodSince(LocalDate fromDate) {
        Long userId = currentUserProvider.getUserId();
        Instant fromInstant = fromDate.atStartOfDay(ZoneId.systemDefault()).toInstant();

        double totalCalories = mealRepository.sumCaloriesSince(userId, fromInstant);
        double totalProtein = mealRepository.sumProteinSince(userId, fromInstant);
        double totalCarbs = mealRepository.sumCarbsSince(userId, fromInstant);
        double totalFat = mealRepository.sumFatSince(userId, fromInstant);
        long workoutCount = workoutSessionRepository.countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual(userId, fromInstant);
        Double latestWeight = weightEntryRepository.findFirstByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(userId)
                .map(WeightEntry::getWeight)
                .orElse(null);
        double totalWater = waterEntryRepository.sumVolumeLitersSince(userId, fromInstant);

        return new StatisticsResponse(totalCalories, totalProtein, totalCarbs, totalFat,
                (int) workoutCount, latestWeight, totalWater);
    }
}
