package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.trainer.ContentAssignmentRepository;
import com.lifey.trainer.PersonalRecordCounter;
import com.lifey.trainer.TrainerClientMapper;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientRevokedEvent;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.dto.MyTrainerResponse;
import com.lifey.trainer.dto.TrainerClientResponse;
import com.lifey.trainer.dto.WeightTrendPoint;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.trainer.exception.NotYourClientException;
import com.lifey.nutrition.meal.MealRepository;
import com.lifey.water.WaterEntryRepository;
import com.lifey.weight.WeightEntry;
import com.lifey.weight.WeightEntryRepository;
import com.lifey.workout.session.WorkoutSessionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional
public class TrainerAccessServiceImpl implements TrainerAccessService {

    /** Sparkline length for the client-card weight trend (06-design.md §3.2). */
    private static final int WEIGHT_TREND_POINTS = 8;

    /** Window used to compute the "workouts/week" average — smooths out a
     *  quiet Monday or a heavy Sunday rather than showing just this week's count. */
    private static final int WORKOUTS_PER_WEEK_WINDOW_DAYS = 28;

    /** Trailing window for the missed-workout compliance count (docs/29) — old
     *  misses shouldn't keep a now-compliant client flagged forever. */
    private static final int MISSED_WORKOUT_WINDOW_DAYS = 14;

    /** Window of the client card's "Avg kcal" and "PRs this week" figures (R6.2). */
    private static final int CARD_WINDOW_DAYS = 7;

    private final TrainerClientRepository trainerClientRepository;
    private final ContentAssignmentRepository contentAssignmentRepository;
    private final WeightEntryRepository weightEntryRepository;
    private final WorkoutSessionRepository workoutSessionRepository;
    private final MealRepository mealRepository;
    private final WaterEntryRepository waterEntryRepository;
    private final CurrentUserProvider currentUserProvider;
    private final ApplicationEventPublisher eventPublisher;

    @Override
    @Transactional(readOnly = true)
    public TrainerClient requireActiveClient(Long trainerId, Long clientId) {
        return trainerClientRepository.findByTrainerIdAndClientIdAndStatus(trainerId, clientId, TrainerClientStatus.ACTIVE)
                .orElseThrow(() -> new NotYourClientException("Not an active client: " + clientId));
    }

    @Override
    @Transactional(readOnly = true)
    public boolean isActivelyLinked(Long userId, Long otherUserId) {
        if (userId == null || otherUserId == null) {
            return false;
        }
        // Both directions, because the caller may be either side of the pair.
        // Two derived finders rather than one hand-written either-direction
        // query: both hit the same index, and the question is asked from a
        // cached avatar request, not from a hot path.
        return trainerClientRepository.existsByTrainerIdAndClientIdAndStatus(
                        userId, otherUserId, TrainerClientStatus.ACTIVE)
                || trainerClientRepository.existsByTrainerIdAndClientIdAndStatus(
                        otherUserId, userId, TrainerClientStatus.ACTIVE);
    }

    @Override
    @Transactional(readOnly = true)
    public List<TrainerClientResponse> findActiveClientsForTrainer() {
        Long trainerId = currentUserProvider.getUserId();
        return trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(
                        trainerId, TrainerClientStatus.ACTIVE)
                .stream()
                .map(tc -> toEnrichedClientResponse(trainerId, tc))
                .toList();
    }

    private TrainerClientResponse toEnrichedClientResponse(Long trainerId, TrainerClient tc) {
        Long clientId = tc.getClient().getId();

        List<WeightEntry> newestFirstWeights = weightEntryRepository
                .findAllByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(
                        clientId, PageRequest.of(0, WEIGHT_TREND_POINTS));
        List<WeightTrendPoint> weightTrend = newestFirstWeights.stream()
                .map(w -> new WeightTrendPoint(w.getDate(), w.getWeight()))
                .collect(Collectors.toCollection(ArrayList::new));
        // Fetched newest-first (for the LIMIT); the sparkline reads left-to-right.
        Collections.reverse(weightTrend);
        LocalDate lastWeightAt = newestFirstWeights.isEmpty() ? null : newestFirstWeights.getFirst().getDate();

        int assignedPlanCount = (int) contentAssignmentRepository.countByTrainerIdAndClientId(trainerId, clientId);

        long recentSessions = workoutSessionRepository.countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual(
                clientId, Instant.now().minus(WORKOUTS_PER_WEEK_WINDOW_DAYS, ChronoUnit.DAYS));
        int workoutsPerWeek = Math.round(recentSessions * 7f / WORKOUTS_PER_WEEK_WINDOW_DAYS);

        Instant lastActivityAt = latestOf(
                mealRepository.findMaxDateTimeByUserId(clientId).orElse(null),
                waterEntryRepository.findMaxConsumedAtByUserId(clientId).orElse(null),
                workoutSessionRepository.findMaxStartedAtByUserId(clientId).orElse(null),
                newestFirstWeights.isEmpty() ? null : newestFirstWeights.getFirst().getRecordedAt());

        LocalDate today = LocalDate.now();
        int missedWorkoutCount = (int) workoutSessionRepository.countMissedOccurrences(
                trainerId, clientId, today.minusDays(MISSED_WORKOUT_WINDOW_DAYS), today);

        Integer avgCalories7d = averageDailyCalories(tc, clientId, today);
        Integer prCount7d = countRecordsThisWeek(clientId);

        return TrainerClientMapper.toClientResponse(
                tc, weightTrend, assignedPlanCount, workoutsPerWeek, lastActivityAt, lastWeightAt, missedWorkoutCount,
                avgCalories7d, prCount7d);
    }

    /**
     * Mean of the daily calorie totals over the last {@value #CARD_WINDOW_DAYS} days, counting only days
     * with something logged — one quiet day must not drag a compliant client's figure down — in the client's
     * own time zone, like the weekly report. Null when nothing was logged.
     */
    private Integer averageDailyCalories(TrainerClient tc, Long clientId, LocalDate today) {
        ZoneOffset zone = ZoneOffset.ofTotalSeconds(tc.getClient().getUtcOffsetMinutes() * 60);
        LocalDate localToday = LocalDate.now(zone);
        int daysLogged = 0;
        double total = 0;
        for (int back = 0; back < CARD_WINDOW_DAYS; back++) {
            LocalDate day = localToday.minusDays(back);
            double calories = mealRepository.sumCaloriesBetween(
                    clientId, day.atStartOfDay(zone).toInstant(), day.plusDays(1).atStartOfDay(zone).toInstant());
            if (calories > 0) {
                daysLogged++;
                total += calories;
            }
        }
        return daysLogged == 0 ? null : (int) Math.round(total / daysLogged);
    }

    private Integer countRecordsThisWeek(Long clientId) {
        List<PersonalRecordCounter.SetFact> facts = workoutSessionRepository
                .findFinishedStrengthSetsOldestFirst(clientId).stream()
                .map(set -> new PersonalRecordCounter.SetFact(
                        set.getWorkoutSession().getId(), set.getWorkoutSession().getStartedAt(),
                        set.getExercise().getId(), set.getWeight(), set.getReps(), set.getPerformedAt()))
                .toList();
        return PersonalRecordCounter.countSince(facts, Instant.now().minus(CARD_WINDOW_DAYS, ChronoUnit.DAYS));
    }

    private static Instant latestOf(Instant... instants) {
        Instant latest = null;
        for (Instant instant : instants) {
            if (instant != null && (latest == null || instant.isAfter(latest))) {
                latest = instant;
            }
        }
        return latest;
    }

    @Override
    public void revokeClient(Long clientId) {
        // Self-invocation bypasses the proxy, so requireActiveClient's own
        // @Transactional(readOnly = true) never applies on this call path —
        // harmless here since this method already opens a (default,
        // read-write) transaction that the guard's read runs inside anyway.
        TrainerClient relationship = requireActiveClient(currentUserProvider.getUserId(), clientId);
        revoke(relationship);
    }

    @Override
    @Transactional(readOnly = true)
    public List<MyTrainerResponse> findActiveTrainersForClient() {
        return trainerClientRepository.findByClientIdAndStatusOrderByRespondedAtDesc(
                        currentUserProvider.getUserId(), TrainerClientStatus.ACTIVE)
                .stream()
                .map(TrainerClientMapper::toMyTrainerResponse)
                .toList();
    }

    @Override
    public void leaveTrainer(Long trainerId) {
        TrainerClient relationship = trainerClientRepository.findByTrainerIdAndClientIdAndStatus(
                        trainerId, currentUserProvider.getUserId(), TrainerClientStatus.ACTIVE)
                .orElseThrow(() -> new ResourceNotFoundException("Trainer not found: " + trainerId));
        revoke(relationship);
    }

    private void revoke(TrainerClient relationship) {
        relationship.setStatus(TrainerClientStatus.REVOKED);
        relationship.setRevokedAt(Instant.now());
        relationship.setRevokedBy(currentUserProvider.getUserId());
        eventPublisher.publishEvent(new TrainerClientRevokedEvent(
                relationship.getTrainer().getId(), relationship.getClient().getId()));
    }
}
