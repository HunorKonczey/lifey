package com.lifey.workout.template;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.template.dto.WorkoutTemplateRequest;
import com.lifey.workout.template.dto.WorkoutTemplateResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class WorkoutTemplateServiceImpl implements WorkoutTemplateService {

    private final WorkoutTemplateRepository templateRepository;
    private final ExerciseRepository exerciseRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    public WorkoutTemplateServiceImpl(WorkoutTemplateRepository templateRepository,
                                      ExerciseRepository exerciseRepository,
                                      UserRepository userRepository,
                                      CurrentUserProvider currentUserProvider) {
        this.templateRepository = templateRepository;
        this.exerciseRepository = exerciseRepository;
        this.userRepository = userRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Override
    @Transactional(readOnly = true)
    public List<WorkoutTemplateResponse> findAll() {
        return templateRepository.findAllByUserId(currentUserProvider.getUserId()).stream()
                .map(WorkoutTemplateMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public WorkoutTemplateResponse findById(Long id) {
        return WorkoutTemplateMapper.toResponse(getOrThrow(id));
    }

    @Override
    public WorkoutTemplateResponse create(WorkoutTemplateRequest request) {
        WorkoutTemplate template = new WorkoutTemplate();
        template.setUser(userRepository.getReferenceById(currentUserProvider.getUserId()));
        template.setName(request.name());
        replaceExercises(template, request.exerciseIds());
        return WorkoutTemplateMapper.toResponse(templateRepository.save(template));
    }

    @Override
    public WorkoutTemplateResponse update(Long id, WorkoutTemplateRequest request) {
        WorkoutTemplate template = getOrThrow(id);
        template.setName(request.name());
        replaceExercises(template, request.exerciseIds());
        return WorkoutTemplateMapper.toResponse(template);
    }

    @Override
    public void delete(Long id) {
        Long userId = currentUserProvider.getUserId();
        if (!templateRepository.existsByIdAndUserId(id, userId)) {
            throw new ResourceNotFoundException("Workout template not found: " + id);
        }
        templateRepository.deleteByIdAndUserId(id, userId);
    }

    private WorkoutTemplate getOrThrow(Long id) {
        return templateRepository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Workout template not found: " + id));
    }

    /**
     * Rebuilds the template's exercise list from the request, resolving each
     * {@code exerciseId}. Relies on {@code orphanRemoval} to delete dropped links.
     */
    private void replaceExercises(WorkoutTemplate template, List<Long> exerciseIds) {
        template.getExercises().clear();
        for (Long exerciseId : exerciseIds) {
            Exercise exercise = exerciseRepository.findById(exerciseId)
                    .orElseThrow(() -> new ResourceNotFoundException("Exercise not found: " + exerciseId));

            WorkoutTemplateExercise link = new WorkoutTemplateExercise();
            link.setWorkoutTemplate(template);
            link.setExercise(exercise);
            template.getExercises().add(link);
        }
    }
}
