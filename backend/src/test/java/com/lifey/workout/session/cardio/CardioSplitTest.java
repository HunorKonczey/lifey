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
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.Statement;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * V68__cardio_splits.sql + the {@link CardioSplit} entity
 * (docs/cardio/52-cardio-domain-backend-plan.md §2.3;
 * docs/cardio/59-cardio-implementation-plan.md C1.3). Runs against a real
 * Postgres to exercise the DB-level invariants: the per-session split-index
 * uniqueness (and that it's scoped *per session*, not global), and the
 * cascade delete.
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

    WorkoutSession cardioSession;

    @BeforeEach
    void seedCardioSession() {
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

    private CardioSplit newSplit(int index, double distanceMeters, int durationSeconds) {
        CardioSplit split = new CardioSplit();
        split.setWorkoutSession(cardioSession);
        split.setSplitIndex(index);
        split.setDistanceMeters(distanceMeters);
        split.setDurationSeconds(durationSeconds);
        return split;
    }

    @Test
    void persistsAndReadsBackTheFullFieldSet() {
        CardioSplit split = newSplit(0, 1000.0, 312);
        split.setElevationDeltaM(-4.5);
        split.setAvgHeartRate(151.0);

        entityManager.persist(split);
        entityManager.flush();
        entityManager.clear();

        CardioSplit reloaded = entityManager.find(CardioSplit.class, split.getId());
        assertThat(reloaded.getWorkoutSession().getId()).isEqualTo(cardioSession.getId());
        assertThat(reloaded.getSplitIndex()).isZero();
        assertThat(reloaded.getDistanceMeters()).isEqualTo(1000.0);
        assertThat(reloaded.getDurationSeconds()).isEqualTo(312);
        assertThat(reloaded.getElevationDeltaM()).isEqualTo(-4.5);
        assertThat(reloaded.getAvgHeartRate()).isEqualTo(151.0);
    }

    @Test
    void elevationAndHeartRateAreOptional() {
        // No altitude or heart-rate data available for this split — must not
        // be forced to a fake 0.
        CardioSplit split = newSplit(0, 1000.0, 300);

        entityManager.persist(split);
        entityManager.flush();

        assertThat(split.getId()).isNotNull();
    }

    @Test
    void multipleSplitsWithDifferentIndexesCoexistForTheSameSession() {
        entityManager.persist(newSplit(0, 1000.0, 300));
        entityManager.persist(newSplit(1, 1000.0, 305));
        entityManager.persist(newSplit(2, 950.0, 290));
        entityManager.flush();
        entityManager.clear();

        List<CardioSplit> splits = entityManager
                .createQuery(
                        "select s from CardioSplit s where s.workoutSession.id = :sessionId order by s.splitIndex",
                        CardioSplit.class)
                .setParameter("sessionId", cardioSession.getId())
                .getResultList();

        assertThat(splits).hasSize(3);
        assertThat(splits).extracting(CardioSplit::getSplitIndex).containsExactly(0, 1, 2);
    }

    @Test
    void aRepeatedSplitIndexForTheSameSessionViolatesTheUniqueConstraint() {
        entityManager.persist(newSplit(0, 1000.0, 300));
        entityManager.flush();

        CardioSplit duplicate = newSplit(0, 990.0, 295);

        // BaseEntity's id is GenerationType.IDENTITY, so Hibernate can't batch
        // the insert — it executes (and the constraint fires) right here on
        // persist(), not on a later flush() (same lesson as CardioDetailsTest).
        assertThatThrownBy(() -> entityManager.persist(duplicate))
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
        otherSession = workoutSessionRepository.save(otherSession);

        CardioSplit first = newSplit(0, 1000.0, 300);
        CardioSplit second = new CardioSplit();
        second.setWorkoutSession(otherSession);
        second.setSplitIndex(0);
        second.setDistanceMeters(1000.0);
        second.setDurationSeconds(600);

        entityManager.persist(first);
        entityManager.persist(second);
        entityManager.flush();

        assertThat(first.getId()).isNotNull();
        assertThat(second.getId()).isNotNull();
    }

    @Test
    void hardDeletingTheSessionCascadesToItsSplits() throws Exception {
        CardioSplit split = newSplit(0, 1000.0, 300);
        entityManager.persist(split);
        entityManager.flush();
        long splitId = split.getId();
        long sessionId = cardioSession.getId();

        // The app itself only ever soft-deletes a WorkoutSession (deletedAt) —
        // this exercises the DB-level ON DELETE CASCADE directly, same as
        // CardioDetailsTest's equivalent case.
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
