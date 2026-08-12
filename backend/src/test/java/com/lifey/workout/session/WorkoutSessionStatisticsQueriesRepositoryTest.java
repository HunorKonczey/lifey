package com.lifey.workout.session;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.session.cardio.ActivityType;
import com.lifey.workout.session.cardio.CardioDetails;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The C3.1 statistics fajta-bontás queries
 * (docs/cardio/56-cardio-statistics-plan.md §2-3, D-C3.2) — the distance/
 * elevation sums join through {@link WorkoutSession#getCardioDetails()},
 * which a mocked-repository unit test (see StatisticsServiceImplTest) can't
 * verify is the right join at all; this runs them against a real Postgres.
 * Mirrors WorkoutSessionKindFilterRepositoryTest's style: repository calls
 * directly, no service/auth layer needed.
 */
@SpringBootTest
@Testcontainers
class WorkoutSessionStatisticsQueriesRepositoryTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    WorkoutSessionRepository workoutSessionRepository;

    Long userId;
    Instant from;

    @BeforeEach
    void seedMixedHistory() {
        User user = new User();
        user.setEmail("statistics-queries-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        userId = userRepository.save(user).getId();

        from = Instant.now().minus(Duration.ofHours(3));

        // One STRENGTH session in range — movingSeconds stays null, no CardioDetails,
        // exactly like a real pre-cardio row.
        WorkoutSession strength = new WorkoutSession();
        strength.setUser(user);
        strength.setStartedAt(Instant.now().minus(Duration.ofHours(2)));
        workoutSessionRepository.save(strength);

        // Two CARDIO sessions in range, each with its own CardioDetails row.
        saveCardioSession(user, Instant.now().minus(Duration.ofMinutes(90)), 1800, 5000.0, 50.0);
        saveCardioSession(user, Instant.now().minus(Duration.ofMinutes(60)), 900, 2000.0, 10.0);

        // A CARDIO session before `from` — must not contribute to any sum/count.
        saveCardioSession(user, Instant.now().minus(Duration.ofHours(10)), 3600, 9999.0, 999.0);

        // A soft-deleted CARDIO session in range — must not contribute either.
        WorkoutSession deleted = new WorkoutSession();
        deleted.setUser(user);
        deleted.setStartedAt(Instant.now().minus(Duration.ofMinutes(30)));
        deleted.setSessionKind(SessionKind.CARDIO);
        deleted.setActivityType(ActivityType.RUNNING);
        deleted.setDeletedAt(Instant.now());
        workoutSessionRepository.save(deleted);
    }

    private void saveCardioSession(User user, Instant startedAt, int movingSeconds,
            double distanceMeters, double elevationGainMeters) {
        WorkoutSession session = new WorkoutSession();
        session.setUser(user);
        session.setStartedAt(startedAt);
        session.setSessionKind(SessionKind.CARDIO);
        session.setActivityType(ActivityType.RUNNING);
        session.setMovingSeconds(movingSeconds);
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(session);
        details.setDistanceMeters(distanceMeters);
        details.setElevationGainMeters(elevationGainMeters);
        session.setCardioDetails(details);
        workoutSessionRepository.save(session);
    }

    @Test
    void cardioCount_countsOnlyInRangeCardioSessions() {
        long cardioCount = workoutSessionRepository
                .countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndSessionKind(userId, from, SessionKind.CARDIO);
        long strengthCount = workoutSessionRepository
                .countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndSessionKind(userId, from, SessionKind.STRENGTH);
        long totalCount = workoutSessionRepository
                .countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual(userId, from);

        assertThat(cardioCount).isEqualTo(2);
        assertThat(strengthCount).isEqualTo(1);
        assertThat(totalCount).isEqualTo(cardioCount + strengthCount);
    }

    @Test
    void movingSeconds_sumsOnlyInRangeCardioSessions() {
        long movingSeconds = workoutSessionRepository.sumMovingSecondsSince(userId, from);

        assertThat(movingSeconds).isEqualTo(1800 + 900);
    }

    @Test
    void distanceAndElevation_sumOnlyInRangeCardioSessions() {
        double distance = workoutSessionRepository.sumDistanceMetersSince(userId, from);
        double elevation = workoutSessionRepository.sumElevationGainMetersSince(userId, from);

        assertThat(distance).isEqualTo(5000.0 + 2000.0);
        assertThat(elevation).isEqualTo(50.0 + 10.0);
    }

    @Test
    void emptyWindow_coalescesToZeroInsteadOfNull() {
        Instant future = Instant.now().plus(Duration.ofDays(1));

        assertThat(workoutSessionRepository.sumMovingSecondsSince(userId, future)).isZero();
        assertThat(workoutSessionRepository.sumDistanceMetersSince(userId, future)).isZero();
        assertThat(workoutSessionRepository.sumElevationGainMetersSince(userId, future)).isZero();
        assertThat(workoutSessionRepository
                .countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndSessionKind(userId, future, SessionKind.CARDIO))
                .isZero();
    }
}
