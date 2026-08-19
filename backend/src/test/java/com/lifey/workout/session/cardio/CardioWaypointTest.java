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
 * V71__cardio_hike_fields.sql's {@code cardio_waypoints} half + the
 * {@link CardioWaypoint} entity (docs/cardio/60 §7 C8.1, docs/cardio/61 §4
 * M41). Runs against a real Postgres to exercise the DB-level invariants:
 * the per-session waypoint-index uniqueness (scoped *per session*, not
 * global), and the cascade delete — the same two invariants
 * {@code CardioSplitTest} checks for splits, since waypoints share the exact
 * same shape.
 *
 * <p>Not {@code @Transactional}, for the same reason as {@code
 * CardioSplitTest}: the cascade test reads through a separate raw-JDBC
 * connection, which wouldn't see a rolled-back write. Each write here commits
 * on its own via {@link #inTransaction}.
 */
@SpringBootTest
@Testcontainers
class CardioWaypointTest {

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
    WorkoutSession hikeSession;

    @BeforeEach
    void seedHikeSession() {
        txTemplate = new TransactionTemplate(transactionManager);

        User user = new User();
        user.setEmail("cardio-waypoints-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        userRepository.save(user);

        WorkoutSession session = new WorkoutSession();
        session.setUser(user);
        session.setStartedAt(Instant.now());
        session.setSessionKind(SessionKind.CARDIO);
        session.setActivityType(ActivityType.HIKING);
        hikeSession = workoutSessionRepository.save(session);
    }

    private void inTransaction(Runnable action) {
        txTemplate.executeWithoutResult(_ -> action.run());
    }

    private <T> T inTransaction(Supplier<T> action) {
        return txTemplate.execute(_ -> action.get());
    }

    private CardioWaypoint newWaypoint(int index, double lat, double lng) {
        CardioWaypoint waypoint = new CardioWaypoint();
        waypoint.setWorkoutSession(hikeSession);
        waypoint.setWaypointIndex(index);
        waypoint.setLatitude(lat);
        waypoint.setLongitude(lng);
        return waypoint;
    }

    @Test
    void persistsAndReadsBackTheFullFieldSet() {
        CardioWaypoint waypoint = newWaypoint(0, 47.4979, 19.0402);
        waypoint.setAltitudeMeters(612.0);

        inTransaction(() -> entityManager.persist(waypoint));
        entityManager.clear();

        CardioWaypoint reloaded = inTransaction(() -> entityManager.find(CardioWaypoint.class, waypoint.getId()));
        assertThat(reloaded.getWorkoutSession().getId()).isEqualTo(hikeSession.getId());
        assertThat(reloaded.getWaypointIndex()).isZero();
        assertThat(reloaded.getLatitude()).isEqualTo(47.4979);
        assertThat(reloaded.getLongitude()).isEqualTo(19.0402);
        assertThat(reloaded.getAltitudeMeters()).isEqualTo(612.0);
        // Always null in V1 (Q-D5) — no input field for it yet.
        assertThat(reloaded.getLabel()).isNull();
    }

    @Test
    void altitudeIsOptional() {
        // A GPS fix with no altitude reading — must not be forced to a fake 0.
        CardioWaypoint waypoint = newWaypoint(0, 47.4979, 19.0402);

        inTransaction(() -> entityManager.persist(waypoint));

        assertThat(waypoint.getId()).isNotNull();
    }

    @Test
    void multipleWaypointsWithDifferentIndexesCoexistForTheSameSession() {
        inTransaction(() -> {
            entityManager.persist(newWaypoint(0, 47.10, 19.00));
            entityManager.persist(newWaypoint(1, 47.20, 19.05));
            entityManager.persist(newWaypoint(2, 47.30, 19.10));
        });
        entityManager.clear();

        List<CardioWaypoint> waypoints = inTransaction(() -> entityManager
                .createQuery(
                        "select w from CardioWaypoint w where w.workoutSession.id = :sessionId order by w.waypointIndex",
                        CardioWaypoint.class)
                .setParameter("sessionId", hikeSession.getId())
                .getResultList());

        assertThat(waypoints).hasSize(3);
        assertThat(waypoints).extracting(CardioWaypoint::getWaypointIndex).containsExactly(0, 1, 2);
    }

    @Test
    void aRepeatedWaypointIndexForTheSameSessionViolatesTheUniqueConstraint() {
        inTransaction(() -> entityManager.persist(newWaypoint(0, 47.10, 19.00)));

        CardioWaypoint duplicate = newWaypoint(0, 47.20, 19.05);

        // IDENTITY generation means Hibernate can't batch the insert — it
        // executes (and the constraint fires) on persist(), not a later
        // flush() (same lesson as CardioSplitTest's equivalent case).
        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(duplicate)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_waypoints_session_index_unique");
    }

    @Test
    void theSameWaypointIndexIsFineAcrossDifferentSessions() {
        WorkoutSession otherSession = new WorkoutSession();
        otherSession.setUser(hikeSession.getUser());
        otherSession.setStartedAt(Instant.now());
        otherSession.setSessionKind(SessionKind.CARDIO);
        otherSession.setActivityType(ActivityType.HIKING);
        WorkoutSession savedOther = workoutSessionRepository.save(otherSession);

        CardioWaypoint first = newWaypoint(0, 47.10, 19.00);
        CardioWaypoint second = new CardioWaypoint();
        second.setWorkoutSession(savedOther);
        second.setWaypointIndex(0);
        second.setLatitude(48.10);
        second.setLongitude(20.00);

        inTransaction(() -> {
            entityManager.persist(first);
            entityManager.persist(second);
        });

        assertThat(first.getId()).isNotNull();
        assertThat(second.getId()).isNotNull();
    }

    @Test
    void hardDeletingTheSessionCascadesToItsWaypoints() throws Exception {
        CardioWaypoint waypoint = newWaypoint(0, 47.10, 19.00);
        inTransaction(() -> entityManager.persist(waypoint));
        long waypointId = waypoint.getId();
        long sessionId = hikeSession.getId();

        // The app itself only ever soft-deletes a WorkoutSession — this
        // exercises the DB-level ON DELETE CASCADE directly, same as
        // CardioSplitTest's equivalent case. The insert above already
        // committed (inTransaction), so this separate raw connection sees it.
        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            st.executeUpdate("delete from workout_sessions where id = " + sessionId);
        }

        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            var rs = st.executeQuery("select count(*) from cardio_waypoints where id = " + waypointId);
            rs.next();
            assertThat(rs.getLong(1)).isZero();
        }
    }
}
