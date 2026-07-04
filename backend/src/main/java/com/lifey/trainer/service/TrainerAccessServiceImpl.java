package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.trainer.ContentAssignmentRepository;
import com.lifey.trainer.TrainerClient;
import com.lifey.trainer.TrainerClientMapper;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.dto.MyTrainerResponse;
import com.lifey.trainer.dto.TrainerClientResponse;
import com.lifey.trainer.dto.WeightTrendPoint;
import com.lifey.trainer.exception.NotYourClientException;
import com.lifey.weight.WeightEntryRepository;
import com.lifey.workout.session.WorkoutSessionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
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

    private final TrainerClientRepository trainerClientRepository;
    private final ContentAssignmentRepository contentAssignmentRepository;
    private final WeightEntryRepository weightEntryRepository;
    private final WorkoutSessionRepository workoutSessionRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public TrainerClient requireActiveClient(Long trainerId, Long clientId) {
        return trainerClientRepository.findByTrainerIdAndClientIdAndStatus(trainerId, clientId, TrainerClientStatus.ACTIVE)
                .orElseThrow(() -> new NotYourClientException("Not an active client: " + clientId));
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

        List<WeightTrendPoint> weightTrend = weightEntryRepository
                .findAllByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(
                        clientId, PageRequest.of(0, WEIGHT_TREND_POINTS))
                .stream()
                .map(w -> new WeightTrendPoint(w.getDate(), w.getWeight()))
                .collect(Collectors.toCollection(ArrayList::new));
        // Fetched newest-first (for the LIMIT); the sparkline reads left-to-right.
        Collections.reverse(weightTrend);

        int assignedPlanCount = (int) contentAssignmentRepository.countByTrainerIdAndClientId(trainerId, clientId);

        long recentSessions = workoutSessionRepository.countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual(
                clientId, Instant.now().minus(WORKOUTS_PER_WEEK_WINDOW_DAYS, ChronoUnit.DAYS));
        int workoutsPerWeek = Math.round(recentSessions * 7f / WORKOUTS_PER_WEEK_WINDOW_DAYS);

        return TrainerClientMapper.toClientResponse(tc, weightTrend, assignedPlanCount, workoutsPerWeek);
    }

    @Override
    public void revokeClient(Long clientId) {
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
    }
}
