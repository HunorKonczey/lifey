package com.lifey.workout.session;

import com.lifey.common.exception.ResourceNotFoundException;
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

    public WorkoutSessionServiceImpl(WorkoutSessionRepository sessionRepository,
                                     ExerciseRepository exerciseRepository) {
        this.sessionRepository = sessionRepository;
        this.exerciseRepository = exerciseRepository;
    }

    @Override
    @Transactional(readOnly = true)
    public List<WorkoutSessionResponse> findAll() {
        return sessionRepository.findAllByOrderByStartedAtDesc().stream()
                .map(WorkoutSessionMapper::toResponse)
                .toList();
    }

    @Override
    public WorkoutSessionResponse create(WorkoutSessionRequest request) {
        WorkoutSession session = new WorkoutSession();
        session.setStartedAt(request.startedAt());
        session.setFinishedAt(request.finishedAt());

        for (ExerciseSetRequest item : request.sets()) {
            Exercise exercise = exerciseRepository.findById(item.exerciseId())
                    .orElseThrow(() -> new ResourceNotFoundException("Exercise not found: " + item.exerciseId()));

            ExerciseSet set = new ExerciseSet();
            set.setWorkoutSession(session);
            set.setExercise(exercise);
            set.setReps(item.reps());
            set.setWeight(item.weight());
            session.getSets().add(set);
        }

        return WorkoutSessionMapper.toResponse(sessionRepository.save(session));
    }
}
