package com.lifey.workout.session.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.session.*;
import com.lifey.workout.session.cardio.CardioDetails;
import com.lifey.workout.session.cardio.CardioSplit;
import com.lifey.workout.session.cardio.InvalidCardioRequestException;
import com.lifey.workout.session.dto.CardioDetailsRequest;
import com.lifey.workout.session.dto.CardioSplitRequest;
import com.lifey.workout.session.dto.ExerciseSetRequest;
import com.lifey.workout.session.dto.PlannedExerciseRequest;
import com.lifey.workout.session.dto.WorkoutSessionRequest;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional
public class WorkoutSessionServiceImpl implements WorkoutSessionService {

    private final WorkoutSessionRepository sessionRepository;
    private final ExerciseRepository exerciseRepository;
    private final UserRepository userRepository;
    private final WorkoutTemplateRepository templateRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public List<WorkoutSessionResponse> findAll(SessionKind kind) {
        Long userId = currentUserProvider.getUserId();
        List<WorkoutSession> sessions = kind == null
                ? sessionRepository.findAllByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullOrderByStartedAtDesc(userId)
                : sessionRepository.findAllByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullAndSessionKindOrderByStartedAtDesc(userId, kind);
        return sessions.stream()
                .map(WorkoutSessionMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<WorkoutSessionResponse> findPage(Pageable pageable, SessionKind kind) {
        Long userId = currentUserProvider.getUserId();
        Page<WorkoutSession> page = kind == null
                ? sessionRepository.findByUserIdAndDeletedAtIsNullAndStartedAtIsNotNull(userId, pageable)
                : sessionRepository.findByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullAndSessionKind(userId, kind, pageable);
        return page.map(WorkoutSessionMapper::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<WorkoutSessionResponse> findPageForUser(Long userId, Pageable pageable) {
        return findPageForUserInternal(userId, pageable);
    }

    /**
     * Shared body for {@link #findPage} and {@link #findPageForUser}, kept
     * un-annotated so calling it from either public method never bypasses
     * the proxy's transaction demarcation (self-invoking an
     * {@code @Transactional} method directly would).
     */
    private Page<WorkoutSessionResponse> findPageForUserInternal(Long userId, Pageable pageable) {
        return sessionRepository.findByUserIdAndDeletedAtIsNullAndStartedAtIsNotNull(userId, pageable)
                .map(WorkoutSessionMapper::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<WorkoutSessionResponse> findDelta(Instant updatedSince, Pageable pageable) {
        // Delta-sync feed: fixed ordering, includes tombstoned rows — see
        // docs/16-delta-sync-rollout.md and WorkoutSessionRepository.findByUserIdAndUpdatedAtGreaterThanEqual.
        Pageable deltaPageable = PageRequest.of(
                pageable.getPageNumber(),
                pageable.getPageSize(),
                Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
        return sessionRepository.findByUserIdAndUpdatedAtGreaterThanEqual(currentUserProvider.getUserId(), updatedSince, deltaPageable)
                .map(WorkoutSessionMapper::toResponse);
    }

    @Override
    public WorkoutSessionResponse create(WorkoutSessionRequest request) {
        validateCardioConsistency(request);
        WorkoutSession session = new WorkoutSession();
        session.setUser(userRepository.getReferenceById(currentUserProvider.getUserId()));
        session.setStartedAt(request.startedAt());
        session.setFinishedAt(request.finishedAt());
        session.setActiveCalories(request.activeCalories());
        session.setAverageHeartRate(request.averageHeartRate());
        session.setHealthWorkoutId(request.healthWorkoutId());
        session.setRpe(request.rpe());
        session.setFeedbackNote(request.feedbackNote());
        session.setSessionKind(request.sessionKind() != null ? request.sessionKind() : SessionKind.STRENGTH);
        session.setActivityType(request.activityType());
        session.setMovingSeconds(request.movingSeconds());
        if (request.templateId() != null) {
            WorkoutTemplate template = templateRepository.findByIdAndUserId(
                            request.templateId(), currentUserProvider.getUserId())
                    .orElseThrow(() -> new ResourceNotFoundException(
                            "Workout template not found: " + request.templateId()));
            session.setTemplate(template);
            session.setTemplateName(template.getName());
        }
        replacePlannedExercises(session, request);
        replaceSets(session, request.sets());
        replaceCardioDetails(session, request.cardio());
        replaceSplits(session, request.splits());
        return WorkoutSessionMapper.toResponse(sessionRepository.save(session));
    }

    @Override
    public WorkoutSessionResponse update(Long id, WorkoutSessionRequest request) {
        validateCardioConsistency(request);
        WorkoutSession session = getOrThrow(id);
        session.setStartedAt(request.startedAt());
        session.setFinishedAt(request.finishedAt());
        session.setActiveCalories(request.activeCalories());
        session.setAverageHeartRate(request.averageHeartRate());
        session.setHealthWorkoutId(request.healthWorkoutId());
        session.setRpe(request.rpe());
        session.setFeedbackNote(request.feedbackNote());
        session.setSessionKind(request.sessionKind() != null ? request.sessionKind() : SessionKind.STRENGTH);
        session.setActivityType(request.activityType());
        session.setMovingSeconds(request.movingSeconds());
        replacePlannedExercises(session, request);
        replaceSets(session, request.sets());
        replaceCardioDetails(session, request.cardio());
        replaceSplits(session, request.splits());
        // Sets/planned exercises/cardio details/splits are child rows with no
        // delta feed of their own (docs/16 §2.3, docs/cardio/52 §4) — a
        // child-only edit could leave every WorkoutSession scalar field
        // unchanged, so Hibernate's dirty-checking could skip @PreUpdate.
        // Bump explicitly so it always fires.
        session.setUpdatedAt(Instant.now());
        return WorkoutSessionMapper.toResponse(session);
    }

    @Override
    public void delete(Long id) {
        WorkoutSession session = getOrThrow(id);
        session.setDeletedAt(Instant.now());
    }

    private WorkoutSession getOrThrow(Long id) {
        return sessionRepository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Workout session not found: " + id));
    }

    /**
     * Rebuilds the session's planned-exercise list from the request, resolving each
     * {@code exerciseId}. Relies on {@code orphanRemoval} to delete dropped links.
     *
     * <p>Reads {@code plannedExercises} when the client sent it (it carries each
     * exercise's {@code targetSets}) and falls back to the bare
     * {@code exerciseIds} otherwise — see {@code WorkoutSessionRequest
     * .plannedExercises}. On that fallback the session's existing targetSets are
     * carried over rather than cleared, so a client that doesn't know about the
     * field (the web app, an older mobile build) can edit a session without
     * silently erasing the plan another client recorded.
     */
    private void replacePlannedExercises(WorkoutSession session, WorkoutSessionRequest request) {
        // What this session already plans, by exercise. Only read on the
        // fallback path: a client that doesn't know about targetSets isn't
        // saying "clear the plan", it simply has nothing to say about it, so
        // its update must not wipe a count another client recorded.
        Map<Long, Integer> existingTargetSets = session.getPlannedExercises().stream()
                .filter(link -> link.getTargetSets() != null)
                .collect(Collectors.toMap(
                        link -> link.getExercise().getId(),
                        WorkoutSessionExercise::getTargetSets,
                        (first, duplicate) -> first));

        List<PlannedExerciseRequest> planned = request.plannedExercises() != null
                ? request.plannedExercises()
                : request.exerciseIds().stream()
                        .map(exerciseId -> new PlannedExerciseRequest(
                                exerciseId, existingTargetSets.get(exerciseId)))
                        .toList();

        session.getPlannedExercises().clear();
        for (PlannedExerciseRequest entry : planned) {
            Long exerciseId = entry.exerciseId();
            Exercise exercise = exerciseRepository.findByIdAndUserId(exerciseId, currentUserProvider.getUserId())
                    .orElseThrow(() -> new ResourceNotFoundException("Exercise not found: " + exerciseId));

            WorkoutSessionExercise link = new WorkoutSessionExercise();
            link.setWorkoutSession(session);
            link.setExercise(exercise);
            link.setTargetSets(entry.targetSets());
            session.getPlannedExercises().add(link);
        }
    }

    /**
     * Rebuilds the session's set list from the request, resolving each
     * {@code exerciseId}. Relies on {@code orphanRemoval} to delete dropped sets.
     *
     * <p>Sets with missing/non-positive reps or a missing/negative weight are
     * dropped rather than rejected — the mobile client can mark a plan row
     * "done" before its reps/weight are filled in (see
     * {@link ExerciseSetRequest}), and such a row is incomplete client state,
     * not a request the whole save should fail for.
     */
    private void replaceSets(WorkoutSession session, List<ExerciseSetRequest> requested) {
        session.getSets().clear();
        for (ExerciseSetRequest item : requested) {
            if (!isComplete(item)) {
                log.warn("Dropping incomplete set for session {} (exerciseId={}, reps={}, weight={})",
                        session.getId(), item.exerciseId(), item.reps(), item.weight());
                continue;
            }
            Exercise exercise = exerciseRepository.findByIdAndUserId(item.exerciseId(), currentUserProvider.getUserId())
                    .orElseThrow(() -> new ResourceNotFoundException("Exercise not found: " + item.exerciseId()));

            ExerciseSet set = new ExerciseSet();
            set.setWorkoutSession(session);
            set.setExercise(exercise);
            set.setReps(item.reps());
            set.setWeight(item.weight());
            set.setPerformedAt(item.performedAt());
            session.getSets().add(set);
        }
    }

    private boolean isComplete(ExerciseSetRequest item) {
        return item.reps() != null && item.reps() > 0
                && item.weight() != null && item.weight() >= 0;
    }

    /**
     * The {@code sessionKind}/{@code activityType}/{@code cardio}/{@code splits}
     * discriminator invariant — the same one {@code workout_sessions_kind_activity_ck}
     * (V66) enforces at the DB layer — checked here so a violation gets a clean
     * 400 instead of bubbling up as a raw constraint-violation 409 from the
     * flush (docs/cardio/52-cardio-domain-backend-plan.md §3.2). Cross-field,
     * so Bean Validation can't express it.
     */
    private void validateCardioConsistency(WorkoutSessionRequest request) {
        SessionKind kind = request.sessionKind() != null ? request.sessionKind() : SessionKind.STRENGTH;
        if (kind == SessionKind.CARDIO) {
            if (request.activityType() == null) {
                throw new InvalidCardioRequestException("activityType is required when sessionKind is CARDIO");
            }
        } else {
            if (request.activityType() != null) {
                throw new InvalidCardioRequestException("activityType must be null unless sessionKind is CARDIO");
            }
            if (request.cardio() != null) {
                throw new InvalidCardioRequestException("cardio must be null unless sessionKind is CARDIO");
            }
            if (request.splits() != null && !request.splits().isEmpty()) {
                throw new InvalidCardioRequestException("splits must be empty unless sessionKind is CARDIO");
            }
        }
    }

    /**
     * Rebuilds the session's cardio-metrics row from the request. Full-replace,
     * same model as {@link #replaceSets}/{@link #replacePlannedExercises}: a
     * null {@code cardio} block clears any existing row (relies on {@code
     * orphanRemoval}) rather than leaving it as-is — the client always sends
     * its complete current cardio state, same as it does for sets.
     */
    private void replaceCardioDetails(WorkoutSession session, CardioDetailsRequest request) {
        if (request == null) {
            session.setCardioDetails(null);
            return;
        }
        CardioDetails details = session.getCardioDetails();
        if (details == null) {
            details = new CardioDetails();
            details.setWorkoutSession(session);
            session.setCardioDetails(details);
        }
        details.setDistanceMeters(request.distanceMeters());
        details.setElevationGainMeters(request.elevationGainMeters());
        details.setElevationLossMeters(request.elevationLossMeters());
        details.setMaxAltitudeMeters(request.maxAltitudeMeters());
        details.setSteps(request.steps());
        details.setAvgCadence(request.avgCadence());
        details.setMaxCadence(request.maxCadence());
        details.setAvgWatts(request.avgWatts());
        details.setMaxWatts(request.maxWatts());
        details.setResistanceLevel(request.resistanceLevel());
        details.setDeviceCalories(request.deviceCalories());
        details.setMaxHeartRate(request.maxHeartRate());
        details.setHrZone1Seconds(request.hrZone1Seconds());
        details.setHrZone2Seconds(request.hrZone2Seconds());
        details.setHrZone3Seconds(request.hrZone3Seconds());
        details.setHrZone4Seconds(request.hrZone4Seconds());
        details.setHrZone5Seconds(request.hrZone5Seconds());
        details.setIntensity(request.intensity());
        details.setVenue(request.venue());
        details.setGameFormat(request.gameFormat());
        details.setScorePoints(request.scorePoints());
        details.setScoreAssists(request.scoreAssists());
        details.setScoreRebounds(request.scoreRebounds());
        details.setDistanceSource(request.distanceSource());
        details.setCaloriesSource(request.caloriesSource());
        details.setRoutePolyline(request.routePolyline());
        details.setRoutePointCount(request.routePointCount());
    }

    /**
     * Rebuilds the session's split list from the request. Full-replace, same
     * model as {@link #replaceSets}. Relies on {@code orphanRemoval} to
     * delete dropped splits.
     */
    private void replaceSplits(WorkoutSession session, List<CardioSplitRequest> requested) {
        session.getSplits().clear();
        if (requested == null) return;
        for (CardioSplitRequest item : requested) {
            CardioSplit split = new CardioSplit();
            split.setWorkoutSession(session);
            split.setSplitIndex(item.splitIndex());
            split.setDistanceMeters(item.distanceMeters());
            split.setDurationSeconds(item.durationSeconds());
            split.setElevationDeltaM(item.elevationDeltaM());
            split.setAvgHeartRate(item.avgHeartRate());
            session.getSplits().add(split);
        }
    }
}
