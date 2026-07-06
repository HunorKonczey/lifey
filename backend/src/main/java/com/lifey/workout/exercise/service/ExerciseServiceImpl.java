package com.lifey.workout.exercise.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseMapper;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.exercise.dto.ExerciseRequest;
import com.lifey.workout.exercise.dto.ExerciseResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional
public class ExerciseServiceImpl implements ExerciseService {

    private final ExerciseRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public List<ExerciseResponse> findAll() {
        return repository.findAllByUserIdAndDeletedAtIsNullOrderByNameAsc(currentUserProvider.getUserId()).stream()
                .map(ExerciseMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<ExerciseResponse> findDelta(Instant updatedSince, Pageable pageable) {
        // Delta-sync feed: fixed ordering, includes tombstoned rows — see
        // docs/16-delta-sync-rollout.md and ExerciseRepository.findByUserIdAndUpdatedAtGreaterThanEqual.
        Pageable deltaPageable = PageRequest.of(
                pageable.getPageNumber(),
                pageable.getPageSize(),
                Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
        return repository.findByUserIdAndUpdatedAtGreaterThanEqual(currentUserProvider.getUserId(), updatedSince, deltaPageable)
                .map(ExerciseMapper::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public ExerciseResponse findById(Long id) {
        return ExerciseMapper.toResponse(getOrThrow(id));
    }

    @Override
    public ExerciseResponse create(ExerciseRequest request) {
        Exercise exercise = ExerciseMapper.toEntity(request);
        exercise.setUser(userRepository.getReferenceById(currentUserProvider.getUserId()));
        return ExerciseMapper.toResponse(repository.save(exercise));
    }

    @Override
    public ExerciseResponse update(Long id, ExerciseRequest request) {
        Exercise exercise = getOrThrow(id);
        ExerciseMapper.apply(exercise, request);
        return ExerciseMapper.toResponse(exercise);
    }

    @Override
    public void delete(Long id) {
        Exercise exercise = getOrThrow(id);
        exercise.setDeletedAt(Instant.now());
    }

    private Exercise getOrThrow(Long id) {
        return repository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Exercise not found: " + id));
    }
}
