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
 * V67__cardio_details.sql + the {@link CardioDetails} entity
 * (docs/cardio/52-cardio-domain-backend-plan.md §2.2, §3.1;
 * docs/cardio/59-cardio-implementation-plan.md C1.2). Runs against a real
 * Postgres so the DB-level invariants (the 1:1 uniqueness, the CHECK
 * constraints, the cascade delete) are actually exercised, not just assumed
 * from the SQL text.
 *
 * <p>Not {@code @Transactional}: that would roll every test back at the end,
 * which would hide the {@link #hardDeletingTheSessionCascadesToItsCardioDetails}
 * test's writes from the separate, non-transactional raw-JDBC connection it
 * uses to check the cascade — a rolled-back write and a genuinely absent
 * cascade would look identical. Instead, each write runs in its own,
 * immediately-committing transaction via {@link #inTransaction}.
 */
@SpringBootTest
@Testcontainers
class CardioDetailsTest {

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
        user.setEmail("cardio-details-" + System.nanoTime() + "@example.com");
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
        txTemplate.executeWithoutResult(_ -> action.run());
    }

    /** Same as {@link #inTransaction(Runnable)}, for reads that return a value. */
    private <T> T inTransaction(Supplier<T> action) {
        return txTemplate.execute(_ -> action.get());
    }

    @Test
    void persistsAndReadsBackTheFullMetricSet() {
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(cardioSession);
        details.setDistanceMeters(7320.5);
        details.setElevationGainMeters(112.0);
        details.setAvgCadence(172.0);
        details.setMaxHeartRate(178.0);
        details.setHrZone3Seconds(900);
        details.setIntensity(4);
        details.setVenue("OUTDOOR");
        details.setDistanceSource("MEASURED");
        details.setRoutePolyline("encoded-polyline-stub");
        details.setRoutePointCount(842);

        inTransaction(() -> entityManager.persist(details));
        entityManager.clear();

        CardioDetails reloaded = inTransaction(() -> entityManager.find(CardioDetails.class, details.getId()));
        assertThat(reloaded.getWorkoutSession().getId()).isEqualTo(cardioSession.getId());
        assertThat(reloaded.getDistanceMeters()).isEqualTo(7320.5);
        assertThat(reloaded.getElevationGainMeters()).isEqualTo(112.0);
        assertThat(reloaded.getAvgCadence()).isEqualTo(172.0);
        assertThat(reloaded.getMaxHeartRate()).isEqualTo(178.0);
        assertThat(reloaded.getHrZone3Seconds()).isEqualTo(900);
        assertThat(reloaded.getIntensity()).isEqualTo(4);
        assertThat(reloaded.getVenue()).isEqualTo("OUTDOOR");
        assertThat(reloaded.getDistanceSource()).isEqualTo("MEASURED");
        assertThat(reloaded.getRoutePolyline()).isEqualTo("encoded-polyline-stub");
        assertThat(reloaded.getRoutePointCount()).isEqualTo(842);
    }

    @Test
    void everyFamilySpecificColumnIsNullableForAnUnfilledField() {
        // A freshly logged session before any metric is filled in — nothing
        // here may be NOT NULL, or a minimal cardio create would fail.
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(cardioSession);

        inTransaction(() -> entityManager.persist(details));

        assertThat(details.getId()).isNotNull();
    }

    @Test
    void aSecondCardioDetailsForTheSameSessionViolatesTheOneToOneUniqueness() {
        CardioDetails first = new CardioDetails();
        first.setWorkoutSession(cardioSession);
        inTransaction(() -> entityManager.persist(first));

        CardioDetails second = new CardioDetails();
        second.setWorkoutSession(cardioSession);

        // BaseEntity's id is GenerationType.IDENTITY, so Hibernate can't batch
        // the insert — it executes (and the constraint fires) right here on
        // persist(), not on a later flush().
        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(second)))
                .isInstanceOf(PersistenceException.class);
    }

    @Test
    void intensityOutsideOneToFiveViolatesTheCheckConstraint() {
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(cardioSession);
        details.setIntensity(6);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(details)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_details_intensity_ck");
    }

    @Test
    void aVenueOutsideIndoorOutdoorViolatesTheCheckConstraint() {
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(cardioSession);
        details.setVenue("SPACE");

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(details)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_details_venue_ck");
    }

    // -- Best efforts, V69__cardio_best_efforts.sql (docs/cardio/60 C6.1) ----

    @Test
    void persistsAndReadsBackTheBestEffortTrio() {
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(cardioSession);
        details.setBest1kSeconds(250);
        details.setBest5kSeconds(1400);
        details.setBest10kSeconds(2980);

        inTransaction(() -> entityManager.persist(details));
        entityManager.clear();

        CardioDetails reloaded = inTransaction(() -> entityManager.find(CardioDetails.class, details.getId()));
        assertThat(reloaded.getBest1kSeconds()).isEqualTo(250);
        assertThat(reloaded.getBest5kSeconds()).isEqualTo(1400);
        assertThat(reloaded.getBest10kSeconds()).isEqualTo(2980);
    }

    @Test
    void aNegativeBestEffortViolatesTheCheckConstraint() {
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(cardioSession);
        details.setBest1kSeconds(-1);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(details)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_details_best_efforts_nonneg_ck");
    }

    @Test
    void aFaster5kThan1kViolatesTheMonotonicityConstraint() {
        // The DB backstop under the service's 400 — a bad best-effort value
        // is silent, it just sits in the PR list forever (docs/cardio/60 §9).
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(cardioSession);
        details.setBest1kSeconds(1500);
        details.setBest5kSeconds(1400);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(details)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_details_best_efforts_monotonic_ck");
    }

    @Test
    void aMissingMiddleValueStillConstrainsTheOuterTwo() {
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(cardioSession);
        details.setBest1kSeconds(3200);
        details.setBest10kSeconds(2980);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(details)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_details_best_efforts_monotonic_ck");
    }

    @Test
    void hardDeletingTheSessionCascadesToItsCardioDetails() throws Exception {
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(cardioSession);
        inTransaction(() -> entityManager.persist(details));
        long detailsId = details.getId();
        long sessionId = cardioSession.getId();

        // The app itself only ever soft-deletes a WorkoutSession (deletedAt),
        // so this exercises the DB-level ON DELETE CASCADE directly — the
        // safety net for any future hard-delete path (e.g. a superadmin
        // purge), not something the mobile/web flow relies on today. The
        // insert above already committed (inTransaction), so this separate
        // raw connection sees it.
        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            st.executeUpdate("delete from workout_sessions where id = " + sessionId);
        }

        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            var rs = st.executeQuery("select count(*) from cardio_details where id = " + detailsId);
            rs.next();
            assertThat(rs.getLong(1)).isZero();
        }
    }
}
