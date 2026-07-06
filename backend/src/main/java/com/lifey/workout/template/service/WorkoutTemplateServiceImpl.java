package com.lifey.workout.template.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateExercise;
import com.lifey.workout.template.WorkoutTemplateMapper;
import com.lifey.workout.template.WorkoutTemplateRepository;
import com.lifey.workout.template.WorkoutTemplateUpdatedEvent;
import com.lifey.workout.template.dto.TemplateExerciseEntry;
import com.lifey.workout.template.dto.WorkoutTemplateRequest;
import com.lifey.workout.template.dto.WorkoutTemplateResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@Transactional
@RequiredArgsConstructor
public class WorkoutTemplateServiceImpl implements WorkoutTemplateService {

    private final WorkoutTemplateRepository templateRepository;
    private final ExerciseRepository exerciseRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;
    private final ApplicationEventPublisher eventPublisher;

    @Override
    @Transactional(readOnly = true)
    public List<WorkoutTemplateResponse> findAll() {
        return templateRepository.findAllByUserIdAndDeletedAtIsNullOrderByNameAsc(currentUserProvider.getUserId()).stream()
                .map(WorkoutTemplateMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<WorkoutTemplateResponse> findDelta(Instant updatedSince, Pageable pageable) {
        // Delta-sync feed: fixed ordering, includes tombstoned rows — see
        // docs/16-delta-sync-rollout.md and WorkoutTemplateRepository.findByUserIdAndUpdatedAtGreaterThanEqual.
        Pageable deltaPageable = PageRequest.of(
                pageable.getPageNumber(),
                pageable.getPageSize(),
                Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
        return templateRepository.findByUserIdAndUpdatedAtGreaterThanEqual(currentUserProvider.getUserId(), updatedSince, deltaPageable)
                .map(WorkoutTemplateMapper::toResponse);
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
        replaceExercises(template, request.exercises());
        return WorkoutTemplateMapper.toResponse(templateRepository.save(template));
    }

    @Override
    public WorkoutTemplateResponse update(Long id, WorkoutTemplateRequest request) {
        WorkoutTemplate template = getOrThrow(id);
        template.setName(request.name());
        replaceExercises(template, request.exercises());
        // Exercise links are child rows with no delta feed of their own (docs/16 §2.3)
        // — a link-only edit (e.g. reordered, target sets changed, name unchanged)
        // would leave WorkoutTemplate's own scalar fields untouched, so Hibernate's
        // dirty-checking could skip @PreUpdate. Bump explicitly so it always fires.
        template.setUpdatedAt(Instant.now());
        // Live-sync: push this edit to every client's already-assigned copy
        // (see AssignedContentSyncListener).
        eventPublisher.publishEvent(new WorkoutTemplateUpdatedEvent(currentUserProvider.getUserId(), template.getId()));
        return WorkoutTemplateMapper.toResponse(template);
    }

    @Override
    public void delete(Long id) {
        WorkoutTemplate template = getOrThrow(id);
        template.setDeletedAt(Instant.now());
    }

    private WorkoutTemplate getOrThrow(Long id) {
        return templateRepository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Workout template not found: " + id));
    }

    /**
     * Rebuilds the template's exercise list from the request, resolving each
     * {@code exerciseId}. Relies on {@code orphanRemoval} to delete dropped links.
     */
    private void replaceExercises(WorkoutTemplate template, List<TemplateExerciseEntry> entries) {
        template.getExercises().clear();
        for (int i = 0; i < entries.size(); i++) {
            TemplateExerciseEntry entry = entries.get(i);
            Exercise exercise = exerciseRepository.findByIdAndUserId(entry.exerciseId(), currentUserProvider.getUserId())
                    .orElseThrow(() -> new ResourceNotFoundException("Exercise not found: " + entry.exerciseId()));

            WorkoutTemplateExercise link = new WorkoutTemplateExercise();
            link.setWorkoutTemplate(template);
            link.setExercise(exercise);
            link.setTargetSets(entry.targetSets());
            link.setSortOrder(i);
            template.getExercises().add(link);
        }
    }
}
