package com.lifey.workout.session;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.session.dto.ExerciseSetRequest;
import com.lifey.workout.session.dto.WorkoutSessionRequest;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class WorkoutSessionServiceImpl implements WorkoutSessionService {

    private final WorkoutSessionRepository sessionRepository;
    private final ExerciseRepository exerciseRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    public WorkoutSessionServiceImpl(WorkoutSessionRepository sessionRepository,
                                     ExerciseRepository exerciseRepository,
                                     UserRepository userRepository,
                                     CurrentUserProvider currentUserProvider) {
        this.sessionRepository = sessionRepository;
        this.exerciseRepository = exerciseRepository;
        this.userRepository = userRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Override
    @Transactional(readOnly = true)
    public List<WorkoutSessionResponse> findAll() {
        return sessionRepository.findAllByUserIdOrderByStartedAtDesc(currentUserProvider.getUserId()).stream()
                .map(WorkoutSessionMapper::toResponse)
                .toList();
    }

    @Override
    public WorkoutSessionResponse create(WorkoutSessionRequest request) {
        WorkoutSession session = new WorkoutSession();
        session.setUser(userRepository.getReferenceById(currentUserProvider.getUserId()));
        session.setStartedAt(request.startedAt());
        session.setFinishedAt(request.finishedAt());
        session.setActiveCalories(request.activeCalories());
        session.setAverageHeartRate(request.averageHeartRate());
        session.setHealthWorkoutId(request.healthWorkoutId());
        replacePlannedExercises(session, request.exerciseIds());
        replaceSets(session, request.sets());
        return WorkoutSessionMapper.toResponse(sessionRepository.save(session));
    }

    @Override
    public WorkoutSessionResponse update(Long id, WorkoutSessionRequest request) {
        WorkoutSession session = getOrThrow(id);
        session.setStartedAt(request.startedAt());
        session.setFinishedAt(request.finishedAt());
        session.setActiveCalories(request.activeCalories());
        session.setAverageHeartRate(request.averageHeartRate());
        session.setHealthWorkoutId(request.healthWorkoutId());
        replacePlannedExercises(session, request.exerciseIds());
        replaceSets(session, request.sets());
        return WorkoutSessionMapper.toResponse(session);
    }

    @Override
    public void delete(Long id) {
        Long userId = currentUserProvider.getUserId();
        if (!sessionRepository.existsByIdAndUserId(id, userId)) {
            throw new ResourceNotFoundException("Workout session not found: " + id);
        }
        sessionRepository.deleteByIdAndUserId(id, userId);
    }

    private WorkoutSession getOrThrow(Long id) {
        return sessionRepository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Workout session not found: " + id));
    }

    /**
     * Rebuilds the session's planned-exercise list from the request, resolving each
     * {@code exerciseId}. Relies on {@code orphanRemoval} to delete dropped links.
     */
    private void replacePlannedExercises(WorkoutSession session, List<Long> exerciseIds) {
        session.getPlannedExercises().clear();
        for (Long exerciseId : exerciseIds) {
            Exercise exercise = exerciseRepository.findById(exerciseId)
                    .orElseThrow(() -> new ResourceNotFoundException("Exercise not found: " + exerciseId));

            WorkoutSessionExercise link = new WorkoutSessionExercise();
            link.setWorkoutSession(session);
            link.setExercise(exercise);
            session.getPlannedExercises().add(link);
        }
    }

    /**
     * Rebuilds the session's set list from the request, resolving each
     * {@code exerciseId}. Relies on {@code orphanRemoval} to delete dropped sets.
     */
    private void replaceSets(WorkoutSession session, List<ExerciseSetRequest> requested) {
        session.getSets().clear();
        for (ExerciseSetRequest item : requested) {
            Exercise exercise = exerciseRepository.findById(item.exerciseId())
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
}
