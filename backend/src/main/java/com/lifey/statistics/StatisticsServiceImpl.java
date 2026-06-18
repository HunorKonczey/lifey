package com.lifey.statistics;

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
 * Aggregates nutrition, workout and weight data over rolling periods ending now.
 */
@Service
@Transactional(readOnly = true)
public class StatisticsServiceImpl implements StatisticsService {

    private final MealRepository mealRepository;
    private final WorkoutSessionRepository workoutSessionRepository;
    private final WeightEntryRepository weightEntryRepository;

    public StatisticsServiceImpl(MealRepository mealRepository,
                                 WorkoutSessionRepository workoutSessionRepository,
                                 WeightEntryRepository weightEntryRepository) {
        this.mealRepository = mealRepository;
        this.workoutSessionRepository = workoutSessionRepository;
        this.weightEntryRepository = weightEntryRepository;
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
        LocalDateTime fromDateTime = fromDate.atStartOfDay();
        Instant fromInstant = fromDate.atStartOfDay(ZoneId.systemDefault()).toInstant();

        double totalCalories = mealRepository.sumCaloriesSince(fromDateTime);
        double totalProtein = mealRepository.sumProteinSince(fromDateTime);
        long workoutCount = workoutSessionRepository.countByStartedAtGreaterThanEqual(fromInstant);
        Double latestWeight = weightEntryRepository.findFirstByOrderByDateDesc()
                .map(WeightEntry::getWeight)
                .orElse(null);

        return new StatisticsResponse(totalCalories, totalProtein, (int) workoutCount, latestWeight);
    }
}
