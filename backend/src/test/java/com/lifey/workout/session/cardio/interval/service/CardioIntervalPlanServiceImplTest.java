package com.lifey.workout.session.cardio.interval.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.domain.BaseEntity;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.session.cardio.IntervalIntensity;
import com.lifey.workout.session.cardio.InvalidCardioRequestException;
import com.lifey.workout.session.cardio.interval.CardioIntervalPlan;
import com.lifey.workout.session.cardio.interval.CardioIntervalStep;
import com.lifey.workout.session.cardio.interval.CardioIntervalPlanRepository;
import com.lifey.workout.session.cardio.interval.IntervalStepType;
import com.lifey.workout.session.cardio.interval.dto.CardioIntervalPlanRequest;
import com.lifey.workout.session.cardio.interval.dto.CardioIntervalPlanResponse;
import com.lifey.workout.session.cardio.interval.dto.IntervalStepEntry;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * The plan CRUD's request-side rules (docs/cardio/60 C7.2): the shape checks
 * that mirror {@code cardio_interval_steps_shape_ck}, the tree-to-rows
 * mapping, and the soft delete. The DB-level invariants and the user scoping
 * are covered against a real Postgres in
 * {@code CardioIntervalPlanCrudIntegrationTest}.
 */
@ExtendWith(MockitoExtension.class)
class CardioIntervalPlanServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    CardioIntervalPlanRepository planRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @Mock
    EntityManager entityManager;

    @InjectMocks
    CardioIntervalPlanServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        User user = new User();
        user.setId(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(user);
        lenient().when(planRepository.save(any(CardioIntervalPlan.class)))
                .thenAnswer(inv -> withId(inv.getArgument(0), 5L));
    }

    private static CardioIntervalPlan withId(CardioIntervalPlan plan, Long id) {
        setId(plan, id);
        return plan;
    }

    private static void setId(BaseEntity entity, Long id) {
        entity.setId(id);
    }

    private static IntervalStepEntry step(String name, IntervalIntensity intensity, Integer durationSeconds) {
        return new IntervalStepEntry(IntervalStepType.STEP, name, intensity, durationSeconds, null, null);
    }

    private static IntervalStepEntry repeat(Integer count, List<IntervalStepEntry> children) {
        return new IntervalStepEntry(IntervalStepType.REPEAT, null, null, null, count, children);
    }

    private static CardioIntervalPlanRequest request(List<IntervalStepEntry> steps) {
        return new CardioIntervalPlanRequest("Kedd esti 4x4", steps);
    }

    private static final List<IntervalStepEntry> FOUR_BY_FOUR = List.of(
            step("Bemelegítés", IntervalIntensity.EASY, 300),
            repeat(4, List.of(
                    step("Kemény", IntervalIntensity.HARD, 240),
                    step("Pihenő", IntervalIntensity.EASY, 180))),
            step("Levezetés", IntervalIntensity.EASY, 300));

    @Test
    void create_flattensTheTreeWithPerSiblingIndexesAndMapsItBack() {
        CardioIntervalPlanResponse result = service.create(request(FOUR_BY_FOUR));

        assertThat(result.name()).isEqualTo("Kedd esti 4x4");
        assertThat(result.steps()).hasSize(3);
        assertThat(result.steps()).extracting(IntervalStepEntry::type)
                .containsExactly(IntervalStepType.STEP, IntervalStepType.REPEAT, IntervalStepType.STEP);
        assertThat(result.steps().get(1).repeatCount()).isEqualTo(4);
        assertThat(result.steps().get(1).children()).extracting(IntervalStepEntry::durationSeconds)
                .containsExactly(240, 180);

        // Stored flat: three top-level rows plus the block's two children, each
        // indexed among its own siblings (0,1,2 and 0,1) — not 0..4.
        CardioIntervalPlan saved = savedPlan();
        assertThat(saved.getSteps()).hasSize(5);
        assertThat(saved.getSteps()).filteredOn(s -> s.getParent() == null)
                .extracting(CardioIntervalStep::getStepIndex).containsExactly(0, 1, 2);
        assertThat(saved.getSteps()).filteredOn(s -> s.getParent() != null)
                .extracting(CardioIntervalStep::getStepIndex).containsExactly(0, 1);
        assertThat(saved.getSteps()).allSatisfy(s -> assertThat(s.getPlan()).isSameAs(saved));
    }

    @Test
    void create_persistsARepeatBlockBeforeItsChildrenAreQueued() {
        // Ids are IDENTITY-generated, so a child can only be inserted once its
        // block has one — the block is the single explicit persist here.
        service.create(request(FOUR_BY_FOUR));

        verify(entityManager).persist(any(CardioIntervalStep.class));
    }

    @Test
    void update_replacesTheStepsAndBumpsUpdatedAt() {
        CardioIntervalPlan existing = existingPlan();
        Instant before = Instant.parse("2026-08-01T05:00:00Z");
        existing.setUpdatedAt(before);
        when(planRepository.findByIdAndUserIdAndDeletedAtIsNull(5L, USER_ID)).thenReturn(Optional.of(existing));

        service.update(5L, new CardioIntervalPlanRequest("Rövid sprintek",
                List.of(repeat(6, List.of(
                        step("Sprint", IntervalIntensity.HARD, 30),
                        step("Pihenő", IntervalIntensity.EASY, 90))))));

        assertThat(existing.getName()).isEqualTo("Rövid sprintek");
        assertThat(existing.getSteps()).hasSize(3);
        // A step-only edit doesn't dirty any scalar of the plan itself, so the
        // service has to bump this by hand or the row never reaches the delta
        // feed (docs/16 §2.3).
        assertThat(existing.getUpdatedAt()).isAfter(before);
    }

    @Test
    void update_rejectedRequestNeverTouchesTheStoredPlan() {
        // Validation runs before the load, so a bad request can't leave a plan
        // half-rewritten — nothing is fetched, nothing is flushed.
        assertThatThrownBy(() -> service.update(5L, request(List.of(
                step("Kemény", null, 240)))))
                .isInstanceOf(InvalidCardioRequestException.class);

        verify(planRepository, never()).findByIdAndUserIdAndDeletedAtIsNull(any(), any());
        verify(entityManager, never()).flush();
    }

    @Test
    void delete_isASoftDeleteAndTouchesNothingElse() {
        CardioIntervalPlan existing = existingPlan();
        when(planRepository.findByIdAndUserIdAndDeletedAtIsNull(5L, USER_ID)).thenReturn(Optional.of(existing));

        service.delete(5L);

        assertThat(existing.getDeletedAt()).isNotNull();
        verify(planRepository, never()).delete(any());
        verify(planRepository, never()).deleteById(any());
    }

    @Test
    void findById_anotherUsersPlanIsNotFound() {
        when(planRepository.findByIdAndUserIdAndDeletedAtIsNull(5L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.findById(5L)).isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void findDelta_isUserScopedAndOrderedByUpdatedAtThenId() {
        CardioIntervalPlan tombstone = existingPlan();
        tombstone.setDeletedAt(Instant.parse("2026-08-18T05:00:00Z"));
        Instant since = Instant.parse("2026-08-17T00:00:00Z");
        Page<CardioIntervalPlan> page = new PageImpl<>(List.of(tombstone));
        when(planRepository.findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), any()))
                .thenReturn(page);

        Page<CardioIntervalPlanResponse> result = service.findDelta(since, PageRequest.of(0, 50));

        assertThat(result.getContent()).singleElement().satisfies(r ->
                assertThat(r.deletedAt()).isEqualTo(tombstone.getDeletedAt()));

        Pageable used = pageableUsedForDelta(since);
        assertThat(used.getSort().toString()).hasToString("updatedAt: ASC,id: ASC");
    }

    // -- Shape rules, mirroring cardio_interval_steps_shape_ck (V70) --------

    @Test
    void create_stepWithoutAnIntensityIsRejected() {
        assertThatThrownBy(() -> service.create(request(List.of(step("Kemény", null, 240)))))
                .isInstanceOf(InvalidCardioRequestException.class)
                .hasMessageContaining("intensity");
    }

    @Test
    void create_stepWithoutADurationIsRejected() {
        assertThatThrownBy(() -> service.create(request(List.of(step("Kemény", IntervalIntensity.HARD, null)))))
                .isInstanceOf(InvalidCardioRequestException.class)
                .hasMessageContaining("durationSeconds");
    }

    @Test
    void create_emptyRepeatBlockIsRejected() {
        assertThatThrownBy(() -> service.create(request(List.of(repeat(4, List.of())))))
                .isInstanceOf(InvalidCardioRequestException.class)
                .hasMessageContaining("at least one step");
    }

    @Test
    void create_repeatBlockWithoutACountIsRejected() {
        assertThatThrownBy(() -> service.create(request(List.of(
                repeat(null, List.of(step("Kemény", IntervalIntensity.HARD, 240)))))))
                .isInstanceOf(InvalidCardioRequestException.class)
                .hasMessageContaining("repeatCount");
    }

    @Test
    void create_nestedRepeatBlockIsRejected() {
        // One level deep, same rule the DB enforces — the editor draws nesting
        // with depth, and a second level has nowhere to go (docs/cardio/61 M37).
        IntervalStepEntry inner = repeat(2, List.of(step("Kemény", IntervalIntensity.HARD, 240)));

        assertThatThrownBy(() -> service.create(request(List.of(repeat(4, List.of(inner))))))
                .isInstanceOf(InvalidCardioRequestException.class)
                .hasMessageContaining("cannot contain another REPEAT");
    }

    @Test
    void create_stepCarryingARepeatCountIsRejected() {
        assertThatThrownBy(() -> service.create(request(List.of(
                new IntervalStepEntry(IntervalStepType.STEP, "Kemény", IntervalIntensity.HARD, 240, 3, null)))))
                .isInstanceOf(InvalidCardioRequestException.class)
                .hasMessageContaining("repeatCount");
    }

    @Test
    void create_repeatBlockCarryingADurationIsRejected() {
        assertThatThrownBy(() -> service.create(request(List.of(
                new IntervalStepEntry(IntervalStepType.REPEAT, null, null, 300, 4,
                        List.of(step("Kemény", IntervalIntensity.HARD, 240)))))))
                .isInstanceOf(InvalidCardioRequestException.class)
                .hasMessageContaining("durationSeconds");
    }

    private CardioIntervalPlan savedPlan() {
        var captor = org.mockito.ArgumentCaptor.forClass(CardioIntervalPlan.class);
        verify(planRepository).save(captor.capture());
        return captor.getValue();
    }

    private Pageable pageableUsedForDelta(Instant since) {
        var captor = org.mockito.ArgumentCaptor.forClass(Pageable.class);
        verify(planRepository).findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), captor.capture());
        return captor.getValue();
    }

    private CardioIntervalPlan existingPlan() {
        CardioIntervalPlan plan = new CardioIntervalPlan();
        setId(plan, 5L);
        plan.setName("Kedd esti 4x4");
        return plan;
    }

}
