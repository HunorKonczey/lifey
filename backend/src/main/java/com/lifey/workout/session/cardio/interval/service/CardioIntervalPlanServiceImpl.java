package com.lifey.workout.session.cardio.interval.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.UserRepository;
import com.lifey.workout.session.cardio.InvalidCardioRequestException;
import com.lifey.workout.session.cardio.interval.CardioIntervalPlan;
import com.lifey.workout.session.cardio.interval.CardioIntervalPlanMapper;
import com.lifey.workout.session.cardio.interval.CardioIntervalPlanRepository;
import com.lifey.workout.session.cardio.interval.CardioIntervalStep;
import com.lifey.workout.session.cardio.interval.IntervalStepType;
import com.lifey.workout.session.cardio.interval.dto.CardioIntervalPlanRequest;
import com.lifey.workout.session.cardio.interval.dto.CardioIntervalPlanResponse;
import com.lifey.workout.session.cardio.interval.dto.IntervalStepEntry;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

/**
 * CRUD for reusable interval plans (docs/cardio/60 C7.2). Deleting a plan is
 * a tombstone, never a cascade into training history: nothing points from a
 * session to a plan in the first place (docs/cardio/60 D-C7.1 — the execution
 * lives in {@code cardio_splits}, carrying its own durations and
 * intensities), so a deleted plan leaves every session run with it exactly as
 * it was.
 */
@Service
@Transactional
@RequiredArgsConstructor
public class CardioIntervalPlanServiceImpl implements CardioIntervalPlanService {

    private final CardioIntervalPlanRepository planRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;
    private final EntityManager entityManager;

    @Override
    @Transactional(readOnly = true)
    public List<CardioIntervalPlanResponse> findAll() {
        return planRepository
                .findAllByUserIdAndDeletedAtIsNullOrderByNameAsc(currentUserProvider.getUserId()).stream()
                .map(CardioIntervalPlanMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<CardioIntervalPlanResponse> findDelta(Instant updatedSince, Pageable pageable) {
        // Delta-sync feed: fixed ordering, includes tombstoned rows — see
        // docs/16-delta-sync-rollout.md and the repository's finder.
        Pageable deltaPageable = PageRequest.of(
                pageable.getPageNumber(),
                pageable.getPageSize(),
                Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
        return planRepository
                .findByUserIdAndUpdatedAtGreaterThanEqual(currentUserProvider.getUserId(), updatedSince, deltaPageable)
                .map(CardioIntervalPlanMapper::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public CardioIntervalPlanResponse findById(Long id) {
        return CardioIntervalPlanMapper.toResponse(getOrThrow(id));
    }

    @Override
    public CardioIntervalPlanResponse create(CardioIntervalPlanRequest request) {
        validateSteps(request.steps());

        CardioIntervalPlan plan = new CardioIntervalPlan();
        plan.setUser(userRepository.getReferenceById(currentUserProvider.getUserId()));
        plan.setName(request.name());
        CardioIntervalPlan saved = planRepository.save(plan);
        addSteps(saved, request.steps());
        return CardioIntervalPlanMapper.toResponse(saved);
    }

    @Override
    public CardioIntervalPlanResponse update(Long id, CardioIntervalPlanRequest request) {
        // Validate before touching anything: a rejected request must leave the
        // stored plan exactly as it was, not half-rewritten.
        validateSteps(request.steps());

        CardioIntervalPlan plan = getOrThrow(id);
        plan.setName(request.name());
        removeAllSteps(plan);
        addSteps(plan, request.steps());
        // Steps are child rows with no delta feed of their own (docs/16 §2.3)
        // — a step-only edit leaves the plan's own scalar fields untouched, so
        // Hibernate's dirty-checking could skip @PreUpdate. Bump explicitly.
        plan.setUpdatedAt(Instant.now());
        return CardioIntervalPlanMapper.toResponse(plan);
    }

    @Override
    public void delete(Long id) {
        // Soft delete: the row stays as a tombstone for the delta feed. It
        // takes nothing else with it — see the class doc.
        getOrThrow(id).setDeletedAt(Instant.now());
    }

    private CardioIntervalPlan getOrThrow(Long id) {
        return planRepository.findByIdAndUserIdAndDeletedAtIsNull(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Cardio interval plan not found: " + id));
    }

    /**
     * Clears the plan's steps in two flushes, children first. The steps form a
     * one-level tree with a self-referencing foreign key, and Hibernate makes
     * no promise about the order of deletes within one flush — a block deleted
     * before the steps inside it would either trip the constraint or (through
     * the DB's {@code on delete cascade}) vanish rows Hibernate still intends
     * to delete itself. Each flush here deletes one level only, so the order
     * within it can't matter.
     */
    private void removeAllSteps(CardioIntervalPlan plan) {
        if (plan.getSteps().isEmpty()) return;

        if (plan.getSteps().removeIf(step -> step.getParent() != null)) {
            entityManager.flush();
        }
        plan.getSteps().clear();
        entityManager.flush();
    }

    /**
     * Appends the request's tree as flat rows: every repeat block goes in
     * before the steps that hang off it, because ids are IDENTITY-generated
     * and a child needs its block's id to exist already.
     */
    private void addSteps(CardioIntervalPlan plan, List<IntervalStepEntry> entries) {
        for (int i = 0; i < entries.size(); i++) {
            IntervalStepEntry entry = entries.get(i);
            CardioIntervalStep step = newStep(plan, null, i, entry);
            plan.getSteps().add(step);

            if (entry.type() != IntervalStepType.REPEAT) continue;

            // The block itself has to be insertable before its children reference it.
            entityManager.persist(step);
            List<IntervalStepEntry> children = entry.children();
            for (int j = 0; j < children.size(); j++) {
                CardioIntervalStep child = newStep(plan, step, j, children.get(j));
                plan.getSteps().add(child);
                // Both sides: the plan's list is what gets written, the
                // block's is what the mapper reads the nesting back from.
                step.getChildren().add(child);
            }
        }
    }

    private CardioIntervalStep newStep(CardioIntervalPlan plan, CardioIntervalStep parent, int index,
                                       IntervalStepEntry entry) {
        CardioIntervalStep step = new CardioIntervalStep();
        step.setPlan(plan);
        step.setParent(parent);
        step.setStepIndex(index);
        step.setStepType(entry.type());
        step.setName(entry.name());
        step.setIntensity(entry.intensity());
        step.setDurationSeconds(entry.durationSeconds());
        step.setRepeatCount(entry.repeatCount());
        return step;
    }

    /**
     * The shape invariants, mirroring {@code cardio_interval_steps_shape_ck}
     * (V70): a STEP is a duration at an intensity, a REPEAT is a count over
     * children, and nesting stops after one level. Cross-field, so Bean
     * Validation can't express it — checked here so a violation gets a clean
     * 400 instead of bubbling up as a raw constraint violation from the flush,
     * the same way the session's cardio invariants are handled
     * (docs/cardio/52 §3.2).
     */
    private void validateSteps(List<IntervalStepEntry> entries) {
        for (IntervalStepEntry entry : entries) {
            validateStep(entry, false);
        }
    }

    private void validateStep(IntervalStepEntry entry, boolean nested) {
        if (entry.type() == IntervalStepType.REPEAT) {
            if (nested) {
                throw new InvalidCardioRequestException("a REPEAT block cannot contain another REPEAT block");
            }
            if (entry.repeatCount() == null) {
                throw new InvalidCardioRequestException("repeatCount is required for a REPEAT block");
            }
            if (entry.children() == null || entry.children().isEmpty()) {
                throw new InvalidCardioRequestException("a REPEAT block must contain at least one step");
            }
            if (entry.durationSeconds() != null || entry.intensity() != null) {
                throw new InvalidCardioRequestException(
                        "durationSeconds and intensity must be null for a REPEAT block");
            }
            for (IntervalStepEntry child : entry.children()) {
                validateStep(child, true);
            }
            return;
        }

        if (entry.intensity() == null) {
            throw new InvalidCardioRequestException("intensity is required for a STEP");
        }
        if (entry.durationSeconds() == null) {
            throw new InvalidCardioRequestException("durationSeconds is required for a STEP");
        }
        if (entry.repeatCount() != null) {
            throw new InvalidCardioRequestException("repeatCount must be null for a STEP");
        }
        if (entry.children() != null && !entry.children().isEmpty()) {
            throw new InvalidCardioRequestException("children must be empty for a STEP");
        }
    }
}
