package com.lifey.workout.session.cardio;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.session.SessionKind;
import com.lifey.workout.session.WorkoutSession;
import com.lifey.workout.session.WorkoutSessionRepository;
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
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

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
 * V68__cardio_splits.sql + V70__cardio_interval_plans.sql + the
 * {@link CardioSplit} entity (docs/cardio/52-cardio-domain-backend-plan.md
 * §2.3; docs/cardio/59-cardio-implementation-plan.md C1.3;
 * docs/cardio/60 D-C7.1). Runs against a real Postgres to exercise the
 * DB-level invariants: the per-session split-index uniqueness (and that it's
 * scoped *per session*, not global), the cascade delete, and the split-type
 * shape rules V70 added for interval sections.
 *
 * <p>Not {@code @Transactional}: that would roll every test back at the end,
 * which would hide the {@link #hardDeletingTheSessionCascadesToItsSplits}
 * test's writes from the separate, non-transactional raw-JDBC connection it
 * uses to check the cascade — a rolled-back write and a genuinely absent
 * cascade would look identical. Instead, each write runs in its own,
 * immediately-committing transaction via {@link #inTransaction}.
 */
@SpringBootTest
@Testcontainers
class CardioSplitTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    WorkoutSessionRepository workoutSessionRepository;

    @Autowired
    DataSource dataSource;

    @PersistenceContext
    EntityManager entityManager;

    @Autowired
    PlatformTransactionManager transactionManager;

    TransactionTemplate txTemplate;
    WorkoutSession cardioSession;

    @BeforeEach
    void seedCardioSession() {
        txTemplate = new TransactionTemplate(transactionManager);

        User user = new User();
        user.setEmail("cardio-splits-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        userRepository.save(user);

        WorkoutSession session = new WorkoutSession();
        session.setUser(user);
        session.setStartedAt(Instant.now());
        session.setSessionKind(SessionKind.CARDIO);
        session.setActivityType(ActivityType.RUNNING);
        cardioSession = workoutSessionRepository.save(session);
    }

    /** Runs a write in its own, immediately-committing transaction — see class doc. */
    private void inTransaction(Runnable action) {
        txTemplate.executeWithoutResult(status -> action.run());
    }

    /** Same as {@link #inTransaction(Runnable)}, for reads that return a value. */
    private <T> T inTransaction(Supplier<T> action) {
        return txTemplate.execute(status -> action.get());
    }

    private CardioSplit newSplit(int index, Double distanceMeters, int durationSeconds) {
        CardioSplit split = new CardioSplit();
        split.setWorkoutSession(cardioSession);
        split.setSplitIndex(index);
        split.setDistanceMeters(distanceMeters);
        split.setDurationSeconds(durationSeconds);
        return split;
    }

    /** An executed section of an interval plan — no distance, see V70. */
    private CardioSplit newIntervalSplit(int index, int durationSeconds, IntervalIntensity intensity) {
        CardioSplit split = new CardioSplit();
        split.setWorkoutSession(cardioSession);
        split.setSplitIndex(index);
        split.setSplitType(SplitType.INTERVAL);
        split.setDurationSeconds(durationSeconds);
        split.setIntensity(intensity);
        return split;
    }

    @Test
    void persistsAndReadsBackTheFullFieldSet() {
        CardioSplit split = newSplit(0, 1000.0, 312);
        split.setElevationDeltaM(-4.5);
        split.setAvgHeartRate(151.0);

        inTransaction(() -> entityManager.persist(split));
        entityManager.clear();

        CardioSplit reloaded = inTransaction(() -> entityManager.find(CardioSplit.class, split.getId()));
        assertThat(reloaded.getWorkoutSession().getId()).isEqualTo(cardioSession.getId());
        assertThat(reloaded.getSplitIndex()).isZero();
        assertThat(reloaded.getDistanceMeters()).isEqualTo(1000.0);
        assertThat(reloaded.getDurationSeconds()).isEqualTo(312);
        assertThat(reloaded.getElevationDeltaM()).isEqualTo(-4.5);
        assertThat(reloaded.getAvgHeartRate()).isEqualTo(151.0);
        // Untouched by the request, so it must land as the per-km split it
        // has always been (V70's column default, docs/cardio/60 C7.1).
        assertThat(reloaded.getSplitType()).isEqualTo(SplitType.DISTANCE);
        assertThat(reloaded.getAvgWatts()).isNull();
        assertThat(reloaded.getIntensity()).isNull();
    }

    // -- Interval sections (V70, docs/cardio/60 D-C7.1) --------------------

    @Test
    void anIntervalSplitPersistsWithoutADistance() {
        // The indoor bike usually reports no distance at all — an interval
        // section is a duration at an intensity, and forcing a fake 0 m here
        // would show up as a 0-length section in the summary.
        CardioSplit split = newIntervalSplit(0, 240, IntervalIntensity.HARD);
        split.setAvgWatts(218.0);

        inTransaction(() -> entityManager.persist(split));
        entityManager.clear();

        CardioSplit reloaded = inTransaction(() -> entityManager.find(CardioSplit.class, split.getId()));
        assertThat(reloaded.getSplitType()).isEqualTo(SplitType.INTERVAL);
        assertThat(reloaded.getDistanceMeters()).isNull();
        assertThat(reloaded.getDurationSeconds()).isEqualTo(240);
        assertThat(reloaded.getIntensity()).isEqualTo(IntervalIntensity.HARD);
        assertThat(reloaded.getAvgWatts()).isEqualTo(218.0);
    }

    @Test
    void distanceAndIntervalSplitsCoexistInOneSession() {
        // Nothing forbids it at the DB level, and the summary's split list
        // renders both from the same rows (docs/cardio/61 §3 M39).
        inTransaction(() -> {
            entityManager.persist(newSplit(0, 1000.0, 300));
            entityManager.persist(newIntervalSplit(1, 240, IntervalIntensity.HARD));
        });
        entityManager.clear();

        List<CardioSplit> splits = inTransaction(() -> entityManager
                .createQuery(
                        "select s from CardioSplit s where s.workoutSession.id = :sessionId order by s.splitIndex",
                        CardioSplit.class)
                .setParameter("sessionId", cardioSession.getId())
                .getResultList());

        assertThat(splits).extracting(CardioSplit::getSplitType)
                .containsExactly(SplitType.DISTANCE, SplitType.INTERVAL);
    }

    @Test
    void aDistanceSplitWithoutADistanceViolatesTheCheckConstraint() {
        // Making the column nullable for intervals must not make it optional
        // for per-km splits — the whole point of a DISTANCE split is the
        // distance.
        CardioSplit split = newSplit(0, null, 300);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(split)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_splits_distance_required_ck");
    }

    @Test
    void anIntensityOnADistanceSplitViolatesTheCheckConstraint() {
        CardioSplit split = newSplit(0, 1000.0, 300);
        split.setIntensity(IntervalIntensity.HARD);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(split)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_splits_intensity_ck");
    }

    @Test
    void aNegativeAveragePowerViolatesTheCheckConstraint() {
        CardioSplit split = newIntervalSplit(0, 240, IntervalIntensity.HARD);
        split.setAvgWatts(-1.0);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(split)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_splits_avg_watts_nonneg_ck");
    }

    @Test
    void elevationAndHeartRateAreOptional() {
        // No altitude or heart-rate data available for this split — must not
        // be forced to a fake 0.
        CardioSplit split = newSplit(0, 1000.0, 300);

        inTransaction(() -> entityManager.persist(split));

        assertThat(split.getId()).isNotNull();
    }

    @Test
    void multipleSplitsWithDifferentIndexesCoexistForTheSameSession() {
        inTransaction(() -> {
            entityManager.persist(newSplit(0, 1000.0, 300));
            entityManager.persist(newSplit(1, 1000.0, 305));
            entityManager.persist(newSplit(2, 950.0, 290));
        });
        entityManager.clear();

        List<CardioSplit> splits = inTransaction(() -> entityManager
                .createQuery(
                        "select s from CardioSplit s where s.workoutSession.id = :sessionId order by s.splitIndex",
                        CardioSplit.class)
                .setParameter("sessionId", cardioSession.getId())
                .getResultList());

        assertThat(splits).hasSize(3);
        assertThat(splits).extracting(CardioSplit::getSplitIndex).containsExactly(0, 1, 2);
    }

    @Test
    void aRepeatedSplitIndexForTheSameSessionViolatesTheUniqueConstraint() {
        inTransaction(() -> entityManager.persist(newSplit(0, 1000.0, 300)));

        CardioSplit duplicate = newSplit(0, 990.0, 295);

        // BaseEntity's id is GenerationType.IDENTITY, so Hibernate can't batch
        // the insert — it executes (and the constraint fires) right here on
        // persist(), not on a later flush() (same lesson as CardioDetailsTest).
        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(duplicate)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_splits_session_index_unique");
    }

    @Test
    void theSameSplitIndexIsFineAcrossDifferentSessions() {
        WorkoutSession otherSession = new WorkoutSession();
        otherSession.setUser(cardioSession.getUser());
        otherSession.setStartedAt(Instant.now());
        otherSession.setSessionKind(SessionKind.CARDIO);
        otherSession.setActivityType(ActivityType.WALKING);
        WorkoutSession savedOther = workoutSessionRepository.save(otherSession);

        CardioSplit first = newSplit(0, 1000.0, 300);
        CardioSplit second = new CardioSplit();
        second.setWorkoutSession(savedOther);
        second.setSplitIndex(0);
        second.setDistanceMeters(1000.0);
        second.setDurationSeconds(600);

        inTransaction(() -> {
            entityManager.persist(first);
            entityManager.persist(second);
        });

        assertThat(first.getId()).isNotNull();
        assertThat(second.getId()).isNotNull();
    }

    @Test
    void hardDeletingTheSessionCascadesToItsSplits() throws Exception {
        CardioSplit split = newSplit(0, 1000.0, 300);
        inTransaction(() -> entityManager.persist(split));
        long splitId = split.getId();
        long sessionId = cardioSession.getId();

        // The app itself only ever soft-deletes a WorkoutSession (deletedAt) —
        // this exercises the DB-level ON DELETE CASCADE directly, same as
        // CardioDetailsTest's equivalent case. The insert above already
        // committed (inTransaction), so this separate raw connection sees it.
        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            st.executeUpdate("delete from workout_sessions where id = " + sessionId);
        }

        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            var rs = st.executeQuery("select count(*) from cardio_splits where id = " + splitId);
            rs.next();
            assertThat(rs.getLong(1)).isZero();
        }
    }
}
