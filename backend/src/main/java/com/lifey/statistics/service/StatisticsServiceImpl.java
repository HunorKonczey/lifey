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
        return dailyForUser(currentUserProvider.getUserId());
    }

    @Override
    public StatisticsResponse daily(LocalDate today) {
        return dailyForUser(currentUserProvider.getUserId(), today);
    }

    @Override
    public StatisticsResponse weekly() {
        return weeklyForUser(currentUserProvider.getUserId());
    }

    @Override
    public StatisticsResponse weekly(LocalDate today) {
        return weeklyForUser(currentUserProvider.getUserId(), today);
    }

    @Override
    public StatisticsResponse monthly() {
        return monthlyForUser(currentUserProvider.getUserId());
    }

    @Override
    public StatisticsResponse monthly(LocalDate today) {
        return monthlyForUser(currentUserProvider.getUserId(), today);
    }

    @Override
    public StatisticsResponse dailyForUser(Long userId) {
        return dailyForUser(userId, todayFor(userId));
    }

    @Override
    public StatisticsResponse weeklyForUser(Long userId) {
        return weeklyForUser(userId, todayFor(userId));
    }

    @Override
    public StatisticsResponse monthlyForUser(Long userId) {
        return monthlyForUser(userId, todayFor(userId));
    }

    /** Today's date on the user's own clock (their stored UTC offset), not the server's. */
    private LocalDate todayFor(Long userId) {
        return LocalDate.now(zoneForUser(userId));
    }

    @Override
    public StatisticsResponse dailyForUser(Long userId, LocalDate today) {
        return forPeriodForUser(userId, today, today.plusDays(1));
    }

    @Override
    public StatisticsResponse weeklyForUser(Long userId, LocalDate today) {
        return forPeriodForUser(userId, today.minusDays(6), today.plusDays(1));
    }

    @Override
    public StatisticsResponse monthlyForUser(Long userId, LocalDate today) {
        return forPeriodForUser(userId, today.minusDays(29), today.plusDays(1));
    }

    /**
     * The period is {@code [fromDate, toExclusiveDate)} in the user's own zone. It used to be "since
     * {@code fromDate}" with no end, so asking for a past date (the web dashboard follows a date picker)
     * answered with the totals of everything after it, as if they were that day's.
     */
    private StatisticsResponse forPeriodForUser(Long userId, LocalDate fromDate, LocalDate toExclusiveDate) {
        ZoneOffset zone = zoneForUser(userId);
        Instant fromInstant = fromDate.atStartOfDay(zone).toInstant();
        Instant toInstant = toExclusiveDate.atStartOfDay(zone).toInstant();

        double totalCalories = mealRepository.sumCaloriesBetween(userId, fromInstant, toInstant);
        double totalProtein = mealRepository.sumProteinBetween(userId, fromInstant, toInstant);
        double totalCarbs = mealRepository.sumCarbsBetween(userId, fromInstant, toInstant);
        double totalFat = mealRepository.sumFatBetween(userId, fromInstant, toInstant);
        // Fibre and sugars are sums of what is known (LIF-148): null when no logged food has a figure, and flagged partial
        // when some do and some do not - never a silent 0 that reads as "no fibre".
        Double totalFiber = mealRepository.sumFiberBetween(userId, fromInstant, toInstant);
        Double totalSugar = mealRepository.sumSugarBetween(userId, fromInstant, toInstant);
        boolean fiberSugarPartial = (totalFiber != null || totalSugar != null)
                && mealRepository.countEntriesMissingFiberOrSugarBetween(userId, fromInstant, toInstant) > 0;
        long workoutCount = workoutSessionRepository.countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThan(userId, fromInstant, toInstant);
        Double latestWeight = weightEntryRepository.findFirstByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(userId)
                .map(WeightEntry::getWeight)
                .orElse(null);
        double totalWater = waterEntryRepository.sumVolumeLitersBetween(userId, fromInstant, toInstant);

        // Additive fajta-bontás (docs/cardio/56-cardio-statistics-plan.md D-C3.2)
        // — workoutCount above keeps its exact pre-cardio meaning and value.
        long cardioWorkoutCount = workoutSessionRepository
                .countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThanAndSessionKind(userId, fromInstant, toInstant, SessionKind.CARDIO);
        long strengthWorkoutCount = workoutCount - cardioWorkoutCount;
        long movingSeconds = workoutSessionRepository.sumMovingSecondsBetween(userId, fromInstant, toInstant);
        double totalDistanceMeters = workoutSessionRepository.sumDistanceMetersBetween(userId, fromInstant, toInstant);
        double totalElevationGainMeters = workoutSessionRepository.sumElevationGainMetersBetween(userId, fromInstant, toInstant);

        return new StatisticsResponse(totalCalories, totalProtein, totalCarbs, totalFat,
                (int) workoutCount, latestWeight, totalWater,
                (int) strengthWorkoutCount, (int) cardioWorkoutCount, (int) (movingSeconds / 60),
                totalDistanceMeters, totalElevationGainMeters, totalFiber, totalSugar, fiberSugarPartial);
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
