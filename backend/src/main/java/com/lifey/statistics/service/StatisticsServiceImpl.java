package com.lifey.statistics.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.nutrition.meal.MealRepository;
import com.lifey.statistics.dto.StatisticsResponse;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.water.WaterEntryRepository;
import com.lifey.weight.WeightEntry;
import com.lifey.weight.WeightEntryRepository;
import com.lifey.workout.session.WorkoutSessionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;

/**
 * Aggregates nutrition, workout and weight data over rolling periods ending now,
 * scoped to the current user.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class StatisticsServiceImpl implements StatisticsService {

    private final MealRepository mealRepository;
    private final WorkoutSessionRepository workoutSessionRepository;
    private final WeightEntryRepository weightEntryRepository;
    private final WaterEntryRepository waterEntryRepository;
    private final CurrentUserProvider currentUserProvider;
    private final UserRepository userRepository;

    @Override
    public StatisticsResponse daily() {
        return daily(LocalDate.now());
    }

    @Override
    public StatisticsResponse daily(LocalDate today) {
        return dailyForUser(currentUserProvider.getUserId(), today);
    }

    @Override
    public StatisticsResponse weekly() {
        return weekly(LocalDate.now());
    }

    @Override
    public StatisticsResponse weekly(LocalDate today) {
        return weeklyForUser(currentUserProvider.getUserId(), today);
    }

    @Override
    public StatisticsResponse monthly() {
        return monthly(LocalDate.now());
    }

    @Override
    public StatisticsResponse monthly(LocalDate today) {
        return monthlyForUser(currentUserProvider.getUserId(), today);
    }

    @Override
    public StatisticsResponse dailyForUser(Long userId, LocalDate today) {
        return forPeriodSinceForUser(userId, today);
    }

    @Override
    public StatisticsResponse weeklyForUser(Long userId, LocalDate today) {
        return forPeriodSinceForUser(userId, today.minusDays(6));
    }

    @Override
    public StatisticsResponse monthlyForUser(Long userId, LocalDate today) {
        return forPeriodSinceForUser(userId, today.minusDays(29));
    }

    private StatisticsResponse forPeriodSinceForUser(Long userId, LocalDate fromDate) {
        ZoneOffset zone = zoneForUser(userId);
        Instant fromInstant = fromDate.atStartOfDay(zone).toInstant();

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

    /**
     * Uses the target user's own local day rather than the server's — same fix as
     * MealServiceImpl#zoneForUser; this endpoint has no upper bound so the bug was
     * latent here, but the two must stay consistent.
     */
    private ZoneOffset zoneForUser(Long userId) {
        return userRepository.findById(userId)
                .map(User::getUtcOffsetMinutes)
                .map(minutes -> ZoneOffset.ofTotalSeconds(minutes * 60))
                .orElse(ZoneOffset.UTC);
    }
}
