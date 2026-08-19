package com.lifey.workout.session.cardio.interval;

import com.lifey.auth.UserPrincipal;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.session.SessionKind;
import com.lifey.workout.session.WorkoutSession;
import com.lifey.workout.session.WorkoutSessionRepository;
import com.lifey.workout.session.cardio.ActivityType;
import com.lifey.workout.session.cardio.CardioSplit;
import com.lifey.workout.session.cardio.IntervalIntensity;
import com.lifey.workout.session.cardio.SplitType;
import com.lifey.workout.session.cardio.interval.dto.CardioIntervalPlanRequest;
import com.lifey.workout.session.cardio.interval.dto.CardioIntervalPlanResponse;
import com.lifey.workout.session.cardio.interval.dto.IntervalStepEntry;
import com.lifey.workout.session.cardio.interval.service.CardioIntervalPlanService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.function.Supplier;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * The plan CRUD end to end against a real Postgres (docs/cardio/60 C7.2):
 * the round-trip through the flat step rows, the full-replace update, the
 * soft delete plus its tombstone in the delta feed, and the two things the
 * step's acceptance criteria name outright — every plan is strictly
 * user-scoped, and deleting a plan leaves the sessions run with it alone.
 *
 * <p>Authentication is set directly on the {@code SecurityContextHolder}
 * rather than mocked: {@code CurrentUserProvider} is what every user-scoping
 * check in the service goes through, so a test that stubbed it would prove
 * only that the stub works.
 */
@SpringBootTest
@Testcontainers
class CardioIntervalPlanCrudIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    CardioIntervalPlanService service;

    @Autowired
    CardioIntervalPlanRepository planRepository;

    @Autowired
    UserRepository userRepository;

    @Autowired
    WorkoutSessionRepository sessionRepository;

    @Autowired
    PlatformTransactionManager transactionManager;

    TransactionTemplate txTemplate;
    User owner;
    User stranger;

    @BeforeEach
    void seedUsers() {
        txTemplate = new TransactionTemplate(transactionManager);
        owner = newUser("owner");
        stranger = newUser("stranger");
        authenticateAs(owner);
    }

    @AfterEach
    void clearAuthentication() {
        SecurityContextHolder.clearContext();
    }

    private User newUser(String prefix) {
        User user = new User();
        user.setEmail(prefix + "-interval-crud-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(user);
    }

    private void authenticateAs(User user) {
        UserPrincipal principal = UserPrincipal.from(user);
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities()));
    }

    private <T> T inTransaction(Supplier<T> action) {
        return txTemplate.execute(status -> action.get());
    }

    private void inTransaction(Runnable action) {
        txTemplate.executeWithoutResult(status -> action.run());
    }

    private static IntervalStepEntry step(String name, IntervalIntensity intensity, int durationSeconds) {
        return new IntervalStepEntry(IntervalStepType.STEP, name, intensity, durationSeconds, null, null);
    }

    private static IntervalStepEntry repeat(int count, List<IntervalStepEntry> children) {
        return new IntervalStepEntry(IntervalStepType.REPEAT, null, null, null, count, children);
    }

    /** 5:00 easy · 4× (4:00 hard + 3:00 easy) · 5:00 easy — the editor's starter template. */
    private static CardioIntervalPlanRequest fourByFour(String name) {
        return new CardioIntervalPlanRequest(name, List.of(
                step("Bemelegítés", IntervalIntensity.EASY, 300),
                repeat(4, List.of(
                        step("Kemény", IntervalIntensity.HARD, 240),
                        step("Pihenő", IntervalIntensity.EASY, 180))),
                step("Levezetés", IntervalIntensity.EASY, 300)));
    }

    private Long createFourByFour() {
        return inTransaction(() -> service.create(fourByFour("Kedd esti 4x4")).id());
    }

    @Test
    void createThenReadBackKeepsTheTreeAndTheOrder() {
        Long id = createFourByFour();

        CardioIntervalPlanResponse reloaded = inTransaction(() -> service.findById(id));

        assertThat(reloaded.name()).isEqualTo("Kedd esti 4x4");
        assertThat(reloaded.steps()).extracting(IntervalStepEntry::type)
                .containsExactly(IntervalStepType.STEP, IntervalStepType.REPEAT, IntervalStepType.STEP);
        assertThat(reloaded.steps().get(0).name()).isEqualTo("Bemelegítés");
        assertThat(reloaded.steps().get(1).repeatCount()).isEqualTo(4);
        assertThat(reloaded.steps().get(1).children()).extracting(IntervalStepEntry::durationSeconds)
                .containsExactly(240, 180);
        assertThat(reloaded.steps().get(2).name()).isEqualTo("Levezetés");
        assertThat(reloaded.deletedAt()).isNull();
    }

    @Test
    void updateReplacesEveryStepIncludingTheOnesInsideABlock() {
        Long id = createFourByFour();

        // A different shape entirely, and the new rows reuse the same sibling
        // indexes the old ones had — the replace has to delete before it
        // inserts or the per-sibling unique index fires.
        inTransaction(() -> service.update(id, new CardioIntervalPlanRequest("Rövid sprintek", List.of(
                repeat(6, List.of(
                        step("Sprint", IntervalIntensity.HARD, 30),
                        step("Pihenő", IntervalIntensity.EASY, 90)))))));

        CardioIntervalPlanResponse reloaded = inTransaction(() -> service.findById(id));
        assertThat(reloaded.name()).isEqualTo("Rövid sprintek");
        assertThat(reloaded.steps()).singleElement().satisfies(block -> {
            assertThat(block.repeatCount()).isEqualTo(6);
            assertThat(block.children()).extracting(IntervalStepEntry::durationSeconds).containsExactly(30, 90);
        });

        // Three rows total (block + two children): nothing from the old plan survived.
        assertThat(countSteps(id)).isEqualTo(3);
    }

    @Test
    void aStepOnlyEditStillReachesTheDeltaFeed() {
        Long id = createFourByFour();
        Instant beforeEdit = Instant.now();

        // Same name, different steps — nothing on the plan row itself changes,
        // so without an explicit bump this edit would never sync (docs/16 §2.3).
        inTransaction(() -> service.update(id, new CardioIntervalPlanRequest("Kedd esti 4x4",
                List.of(step("Bemelegítés", IntervalIntensity.EASY, 600)))));

        List<CardioIntervalPlanResponse> delta = inTransaction(() ->
                service.findDelta(beforeEdit, PageRequest.of(0, 50)).getContent());
        assertThat(delta).extracting(CardioIntervalPlanResponse::id).contains(id);
    }

    @Test
    void deleteIsATombstoneThatLeavesTheListButNotTheDeltaFeed() {
        Long id = createFourByFour();
        Instant beforeDelete = Instant.now();

        inTransaction(() -> service.delete(id));

        assertThat(inTransaction(() -> service.findAll())).isEmpty();
        assertThatThrownBy(() -> inTransaction(() -> service.findById(id)))
                .isInstanceOf(ResourceNotFoundException.class);

        List<CardioIntervalPlanResponse> delta = inTransaction(() ->
                service.findDelta(beforeDelete, PageRequest.of(0, 50)).getContent());
        assertThat(delta).singleElement().satisfies(plan -> {
            assertThat(plan.id()).isEqualTo(id);
            assertThat(plan.deletedAt()).isNotNull();
        });
    }

    @Test
    void deletingAPlanLeavesTheSessionsRunWithItUntouched() {
        // The point of D-C7.1: the execution lives in cardio_splits, with no
        // reference back to the plan, so a deleted plan can't take training
        // history with it — not even by cascade.
        Long id = createFourByFour();
        Long sessionId = inTransaction(() -> {
            WorkoutSession session = new WorkoutSession();
            session.setUser(owner);
            session.setStartedAt(Instant.now());
            session.setSessionKind(SessionKind.CARDIO);
            session.setActivityType(ActivityType.INDOOR_BIKE);
            session.setMovingSeconds(1800);

            CardioSplit executed = new CardioSplit();
            executed.setWorkoutSession(session);
            executed.setSplitIndex(0);
            executed.setSplitType(SplitType.INTERVAL);
            executed.setDurationSeconds(240);
            executed.setIntensity(IntervalIntensity.HARD);
            executed.setAvgWatts(218.0);
            session.getSplits().add(executed);

            return sessionRepository.save(session).getId();
        });

        inTransaction(() -> service.delete(id));

        inTransaction(() -> {
            WorkoutSession session = sessionRepository.findById(sessionId).orElseThrow();
            assertThat(session.getDeletedAt()).isNull();
            assertThat(session.getSplits()).singleElement().satisfies(split -> {
                assertThat(split.getSplitType()).isEqualTo(SplitType.INTERVAL);
                assertThat(split.getIntensity()).isEqualTo(IntervalIntensity.HARD);
                assertThat(split.getDurationSeconds()).isEqualTo(240);
            });
            return null;
        });
    }

    // -- User scoping (the step's other acceptance criterion) ---------------

    @Test
    void anotherUserCannotReadUpdateOrDeleteThePlan() {
        Long id = createFourByFour();
        authenticateAs(stranger);

        assertThat(inTransaction(() -> service.findAll())).isEmpty();
        assertThatThrownBy(() -> inTransaction(() -> service.findById(id)))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> inTransaction(() -> service.update(id, fourByFour("Eltérítve"))))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> inTransaction(() -> {
            service.delete(id);
            return null;
        })).isInstanceOf(ResourceNotFoundException.class);

        // And it survived all four attempts intact.
        authenticateAs(owner);
        assertThat(inTransaction(() -> service.findById(id)).name()).isEqualTo("Kedd esti 4x4");
    }

    @Test
    void theDeltaFeedNeverLeaksAnotherUsersPlan() {
        Instant since = Instant.now().minusSeconds(60);
        createFourByFour();
        authenticateAs(stranger);

        assertThat(inTransaction(() -> service.findDelta(since, PageRequest.of(0, 50)).getContent())).isEmpty();
    }

    private long countSteps(Long planId) {
        return inTransaction(() -> planRepository.findById(planId).orElseThrow().getSteps().size()).longValue();
    }
}
