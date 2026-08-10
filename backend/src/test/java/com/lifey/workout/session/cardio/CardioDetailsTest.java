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
 * V67__cardio_details.sql + the {@link CardioDetails} entity
 * (docs/cardio/52-cardio-domain-backend-plan.md §2.2, §3.1;
 * docs/cardio/59-cardio-implementation-plan.md C1.2). Runs against a real
 * Postgres so the DB-level invariants (the 1:1 uniqueness, the CHECK
 * constraints, the cascade delete) are actually exercised, not just assumed
 * from the SQL text.
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

    WorkoutSession cardioSession;

    @BeforeEach
    void seedCardioSession() {
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

        entityManager.persist(details);
        entityManager.flush();
        entityManager.clear();

        CardioDetails reloaded = entityManager.find(CardioDetails.class, details.getId());
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

        entityManager.persist(details);
        entityManager.flush();

        assertThat(details.getId()).isNotNull();
    }

    @Test
    void aSecondCardioDetailsForTheSameSessionViolatesTheOneToOneUniqueness() {
        CardioDetails first = new CardioDetails();
        first.setWorkoutSession(cardioSession);
        entityManager.persist(first);
        entityManager.flush();

        CardioDetails second = new CardioDetails();
        second.setWorkoutSession(cardioSession);

        // BaseEntity's id is GenerationType.IDENTITY, so Hibernate can't batch
        // the insert — it executes (and the constraint fires) right here on
        // persist(), not on a later flush().
        assertThatThrownBy(() -> entityManager.persist(second))
                .isInstanceOf(PersistenceException.class);
    }

    @Test
    void intensityOutsideOneToFiveViolatesTheCheckConstraint() {
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(cardioSession);
        details.setIntensity(6);

        assertThatThrownBy(() -> entityManager.persist(details))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_details_intensity_ck");
    }

    @Test
    void aVenueOutsideIndoorOutdoorViolatesTheCheckConstraint() {
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(cardioSession);
        details.setVenue("SPACE");

        assertThatThrownBy(() -> entityManager.persist(details))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_details_venue_ck");
    }

    @Test
    void hardDeletingTheSessionCascadesToItsCardioDetails() throws Exception {
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(cardioSession);
        entityManager.persist(details);
        entityManager.flush();
        long detailsId = details.getId();
        long sessionId = cardioSession.getId();

        // The app itself only ever soft-deletes a WorkoutSession (deletedAt),
        // so this exercises the DB-level ON DELETE CASCADE directly — the
        // safety net for any future hard-delete path (e.g. a superadmin
        // purge), not something the mobile/web flow relies on today.
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
