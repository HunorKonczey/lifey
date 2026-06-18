package com.lifey.workout.template;

import com.lifey.common.exception.ResourceNotFoundException;
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

    public WorkoutTemplateServiceImpl(WorkoutTemplateRepository templateRepository,
                                      ExerciseRepository exerciseRepository) {
        this.templateRepository = templateRepository;
        this.exerciseRepository = exerciseRepository;
    }

    @Override
    @Transactional(readOnly = true)
    public List<WorkoutTemplateResponse> findAll() {
        return templateRepository.findAll().stream()
                .map(WorkoutTemplateMapper::toResponse)
                .toList();
    }

    @Override
    public WorkoutTemplateResponse create(WorkoutTemplateRequest request) {
        WorkoutTemplate template = new WorkoutTemplate();
        template.setName(request.name());

        for (Long exerciseId : request.exerciseIds()) {
            Exercise exercise = exerciseRepository.findById(exerciseId)
                    .orElseThrow(() -> new ResourceNotFoundException("Exercise not found: " + exerciseId));

            WorkoutTemplateExercise link = new WorkoutTemplateExercise();
            link.setWorkoutTemplate(template);
            link.setExercise(exercise);
            template.getExercises().add(link);
        }

        return WorkoutTemplateMapper.toResponse(templateRepository.save(template));
    }
}
