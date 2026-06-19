package com.lifey.statistics;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.nutrition.meal.MealRepository;
import com.lifey.statistics.dto.StatisticsResponse;
import com.lifey.weight.WeightEntry;
import com.lifey.weight.WeightEntryRepository;
import com.lifey.workout.session.WorkoutSessionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
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
    private final CurrentUserProvider currentUserProvider;

    public StatisticsServiceImpl(MealRepository mealRepository,
                                 WorkoutSessionRepository workoutSessionRepository,
                                 WeightEntryRepository weightEntryRepository,
                                 CurrentUserProvider currentUserProvider) {
        this.mealRepository = mealRepository;
        this.workoutSessionRepository = workoutSessionRepository;
        this.weightEntryRepository = weightEntryRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Override
    public StatisticsResponse daily() {
        return forPeriodSince(LocalDate.now());
    }

    @Override
    public StatisticsResponse weekly() {
        return forPeriodSince(LocalDate.now().minusDays(6));
    }

    @Override
    public StatisticsResponse monthly() {
        return forPeriodSince(LocalDate.now().minusDays(29));
    }

    private StatisticsResponse forPeriodSince(LocalDate fromDate) {
        Long userId = currentUserProvider.getUserId();
        LocalDateTime fromDateTime = fromDate.atStartOfDay();
        Instant fromInstant = fromDate.atStartOfDay(ZoneId.systemDefault()).toInstant();

        double totalCalories = mealRepository.sumCaloriesSince(userId, fromDateTime);
        double totalProtein = mealRepository.sumProteinSince(userId, fromDateTime);
        double totalCarbs = mealRepository.sumCarbsSince(userId, fromDateTime);
        double totalFat = mealRepository.sumFatSince(userId, fromDateTime);
        long workoutCount = workoutSessionRepository.countByUserIdAndStartedAtGreaterThanEqual(userId, fromInstant);
        Double latestWeight = weightEntryRepository.findFirstByUserIdOrderByDateDescRecordedAtDesc(userId)
                .map(WeightEntry::getWeight)
                .orElse(null);

        return new StatisticsResponse(totalCalories, totalProtein, totalCarbs, totalFat,
                (int) workoutCount, latestWeight);
    }
}
