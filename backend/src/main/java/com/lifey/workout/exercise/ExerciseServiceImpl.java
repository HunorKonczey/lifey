package com.lifey.workout.exercise;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.workout.exercise.dto.ExerciseRequest;
import com.lifey.workout.exercise.dto.ExerciseResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class ExerciseServiceImpl implements ExerciseService {

    private final ExerciseRepository repository;

    public ExerciseServiceImpl(ExerciseRepository repository) {
        this.repository = repository;
    }

    @Override
    @Transactional(readOnly = true)
    public List<ExerciseResponse> findAll() {
        return repository.findAllByOrderByNameAsc().stream()
                .map(ExerciseMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public ExerciseResponse findById(Long id) {
        return ExerciseMapper.toResponse(getOrThrow(id));
    }

    @Override
    public ExerciseResponse create(ExerciseRequest request) {
        return ExerciseMapper.toResponse(repository.save(ExerciseMapper.toEntity(request)));
    }

    @Override
    public ExerciseResponse update(Long id, ExerciseRequest request) {
        Exercise exercise = getOrThrow(id);
        ExerciseMapper.apply(exercise, request);
        return ExerciseMapper.toResponse(exercise);
    }

    @Override
    public void delete(Long id) {
        if (!repository.existsById(id)) {
            throw new ResourceNotFoundException("Exercise not found: " + id);
        }
        repository.deleteById(id);
    }

    private Exercise getOrThrow(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Exercise not found: " + id));
    }
}
