package com.lifey.workout.session.cardio.interval;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.session.cardio.IntervalIntensity;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.PersistenceException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.Statement;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.function.Supplier;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * V70__cardio_interval_plans.sql + the {@link CardioIntervalPlan} /
 * {@link CardioIntervalStep} entities (docs/cardio/60 §6 C7.1, D-C7.1). Runs
 * against a real Postgres for the invariants that only exist there: the
 * one-level nesting rule, the two row shapes, sibling-index uniqueness
 * (including at the top level, where the parent is null), and the fact that a
 * step can't be re-parented into someone else's plan.
 *
 * <p>Not {@code @Transactional}, for the same reason as {@code
 * CardioSplitTest}: the cascade check reads through a separate raw-JDBC
 * connection, which would not see rolled-back writes — each write here
 * commits on its own via {@link #inTransaction}.
 */
@SpringBootTest
@Testcontainers
class CardioIntervalPlanTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    DataSource dataSource;

    @PersistenceContext
    EntityManager entityManager;

    @Autowired
    PlatformTransactionManager transactionManager;

    TransactionTemplate txTemplate;
    User owner;
    CardioIntervalPlan plan;

    @BeforeEach
    void seedPlan() {
        txTemplate = new TransactionTemplate(transactionManager);
        owner = newUser();

        CardioIntervalPlan fresh = new CardioIntervalPlan();
        fresh.setUser(owner);
        fresh.setName("Kedd esti 4x4");
        inTransaction(() -> entityManager.persist(fresh));
        plan = fresh;
    }

    private User newUser() {
        User user = new User();
        user.setEmail("cardio-interval-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(user);
    }

    /** Runs a write in its own, immediately-committing transaction — see class doc. */
    private void inTransaction(Runnable action) {
        txTemplate.executeWithoutResult(status -> action.run());
    }

    /** Same as {@link #inTransaction(Runnable)}, for reads that return a value. */
    private <T> T inTransaction(Supplier<T> action) {
        return txTemplate.execute(status -> action.get());
    }

    private CardioIntervalStep step(CardioIntervalPlan owningPlan, CardioIntervalStep parent, int index,
                                    String name, IntervalIntensity intensity, Integer durationSeconds) {
        CardioIntervalStep step = new CardioIntervalStep();
        step.setPlan(owningPlan);
        step.setParent(parent);
        step.setStepIndex(index);
        step.setStepType(IntervalStepType.STEP);
        step.setName(name);
        step.setIntensity(intensity);
        step.setDurationSeconds(durationSeconds);
        return step;
    }

    private CardioIntervalStep repeatBlock(int index, int repeatCount) {
        CardioIntervalStep block = new CardioIntervalStep();
        block.setPlan(plan);
        block.setStepIndex(index);
        block.setStepType(IntervalStepType.REPEAT);
        block.setRepeatCount(repeatCount);
        return block;
    }

    @Test
    void persistsTheFourByFourPlanAsWarmupRepeatBlockCooldown() {
        // The template the editor offers on the empty state (docs/cardio/61
        // §3 M37): 5:00 warm-up, 4x (4:00 hard + 3:00 easy), 5:00 cool-down —
        // three top-level items, not ten.
        CardioIntervalStep warmup = step(plan, null, 0, "Bemelegítés", IntervalIntensity.EASY, 300);
        CardioIntervalStep block = repeatBlock(1, 4);
        CardioIntervalStep cooldown = step(plan, null, 2, "Levezetés", IntervalIntensity.EASY, 300);

        inTransaction(() -> {
            entityManager.persist(warmup);
            entityManager.persist(block);
            entityManager.persist(cooldown);
            // The block has to exist before its children can point at it.
            entityManager.persist(step(plan, block, 0, "Kemény", IntervalIntensity.HARD, 240));
            entityManager.persist(step(plan, block, 1, "Pihenő", IntervalIntensity.EASY, 180));
        });
        entityManager.clear();

        CardioIntervalPlan reloaded = inTransaction(() -> {
            CardioIntervalPlan found = entityManager.find(CardioIntervalPlan.class, plan.getId());
            found.getSteps().forEach(s -> s.getChildren().size());
            return found;
        });

        assertThat(reloaded.getName()).isEqualTo("Kedd esti 4x4");
        assertThat(reloaded.getUpdatedAt()).isNotNull();
        assertThat(reloaded.getSteps()).hasSize(5);

        List<CardioIntervalStep> topLevel = reloaded.getSteps().stream()
                .filter(s -> s.getParent() == null)
                .toList();
        assertThat(topLevel).hasSize(3);
        assertThat(topLevel).extracting(CardioIntervalStep::getStepType)
                .containsExactly(IntervalStepType.STEP, IntervalStepType.REPEAT, IntervalStepType.STEP);

        CardioIntervalStep reloadedBlock = topLevel.get(1);
        assertThat(reloadedBlock.getRepeatCount()).isEqualTo(4);
        assertThat(reloadedBlock.getChildren()).extracting(CardioIntervalStep::getIntensity)
                .containsExactly(IntervalIntensity.HARD, IntervalIntensity.EASY);
        assertThat(reloadedBlock.getChildren()).extracting(CardioIntervalStep::getDurationSeconds)
                .containsExactly(240, 180);
    }

    @Test
    void aRepeatBlockInsideARepeatBlockViolatesTheCheckConstraint() {
        // One level of nesting only — the editor draws depth with background
        // tone, not indentation (docs/cardio/61 §3 M37), and a second level
        // would have nowhere to go on a 390 px screen.
        CardioIntervalStep block = repeatBlock(0, 4);
        inTransaction(() -> entityManager.persist(block));

        CardioIntervalStep nested = repeatBlock(0, 2);
        nested.setParent(block);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(nested)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_interval_steps_shape_ck");
    }

    @Test
    void aStepWithoutADurationViolatesTheCheckConstraint() {
        CardioIntervalStep step = step(plan, null, 0, "Bemelegítés", IntervalIntensity.EASY, null);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(step)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_interval_steps_shape_ck");
    }

    @Test
    void aStepWithoutAnIntensityViolatesTheCheckConstraint() {
        // A null here would slip through a naively written CHECK (null
        // propagates, and a CHECK accepts null) — the constraint spells out
        // `is not null` for exactly this case.
        CardioIntervalStep step = step(plan, null, 0, "Bemelegítés", null, 300);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(step)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_interval_steps_shape_ck");
    }

    @Test
    void aRepeatBlockCarryingADurationViolatesTheCheckConstraint() {
        CardioIntervalStep block = repeatBlock(0, 4);
        block.setDurationSeconds(300);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(block)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_interval_steps_shape_ck");
    }

    @Test
    void twoTopLevelStepsAtTheSameIndexViolateTheUniqueConstraint() {
        // The top level is where parent_step_id is null, so this only holds
        // because the unique constraint is `nulls not distinct`.
        inTransaction(() -> entityManager.persist(step(plan, null, 0, "A", IntervalIntensity.EASY, 300)));

        CardioIntervalStep duplicate = step(plan, null, 0, "B", IntervalIntensity.HARD, 240);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(duplicate)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_interval_steps_sibling_index_unique");
    }

    @Test
    void theSameIndexIsFineInsideARepeatBlockAndAtTheTopLevel() {
        CardioIntervalStep block = repeatBlock(0, 4);
        CardioIntervalStep child = step(plan, block, 0, "Kemény", IntervalIntensity.HARD, 240);

        // Index 0 is taken at the top level (by the block) and inside the
        // block — different sibling sets, so both are fine.
        inTransaction(() -> {
            entityManager.persist(block);
            entityManager.persist(child);
        });

        assertThat(block.getId()).isNotNull();
        assertThat(child.getId()).isNotNull();
    }

    @Test
    void aStepCannotBeParentedIntoAnotherPlansBlock() {
        // Enforced by the composite (parent_step_id, plan_id) foreign key —
        // otherwise a mis-built request could splice one user's step into
        // another user's plan and only application code would notice.
        CardioIntervalPlan otherPlan = new CardioIntervalPlan();
        otherPlan.setUser(newUser());
        otherPlan.setName("Valaki mase");
        CardioIntervalStep otherBlock = repeatBlock(0, 4);
        otherBlock.setPlan(otherPlan);
        inTransaction(() -> {
            entityManager.persist(otherPlan);
            entityManager.persist(otherBlock);
        });

        CardioIntervalStep trespasser = step(plan, otherBlock, 0, "Kemény", IntervalIntensity.HARD, 240);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(trespasser)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_interval_steps_parent_fk");
    }

    @Test
    void hardDeletingThePlanCascadesToItsStepsAndTheirChildren() throws Exception {
        CardioIntervalStep block = repeatBlock(0, 4);
        CardioIntervalStep child = step(plan, block, 0, "Kemény", IntervalIntensity.HARD, 240);
        inTransaction(() -> {
            entityManager.persist(block);
            entityManager.persist(child);
        });
        long planId = plan.getId();

        // The app itself soft-deletes a plan (deletedAt) — this exercises the
        // DB-level ON DELETE CASCADE directly, including the self-referencing
        // one from block to child. The inserts above already committed, so
        // this separate raw connection sees them.
        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            st.executeUpdate("delete from cardio_interval_plans where id = " + planId);
        }

        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            var rs = st.executeQuery("select count(*) from cardio_interval_steps where plan_id = " + planId);
            rs.next();
            assertThat(rs.getLong(1)).isZero();
        }
    }
}
