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
 * The C3.5 weekly-trainer-report queries (docs/cardio/56-cardio-statistics-plan.md
 * §6 ST9) — bounded (not open-ended, unlike WorkoutSessionStatisticsQueriesRepositoryTest)
 * and restricted to completed sessions only, since an in-progress session inside an
 * already-elapsed report week is an abandoned one. Runs against a real Postgres for
 * the same reason as its sibling: the distance sum joins through
 * {@link WorkoutSession#getCardioDetails()}, which a mocked-repository test can't verify.
 */
@SpringBootTest
@Testcontainers
class WorkoutSessionWeeklyReportQueriesRepositoryTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    WorkoutSessionRepository workoutSessionRepository;

    Long userId;
    Instant from;
    Instant toExclusive;

    @BeforeEach
    void seedWeekHistory() {
        User user = new User();
        user.setEmail("weekly-report-queries-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        userId = userRepository.save(user).getId();

        from = Instant.now().minus(Duration.ofDays(7));
        toExclusive = Instant.now();

        // Two completed CARDIO sessions in range.
        saveCardioSession(user, Instant.now().minus(Duration.ofDays(5)), true, 4000.0);
        saveCardioSession(user, Instant.now().minus(Duration.ofDays(3)), true, 6000.0);

        // A still-in-progress CARDIO session in range — an abandoned session by the
        // time a week-old report runs; must not contribute to either query.
        saveCardioSession(user, Instant.now().minus(Duration.ofDays(2)), false, 9999.0);

        // A completed STRENGTH session in range — counts toward the unscoped
        // completed total but not the CARDIO-scoped count or the distance sum.
        WorkoutSession strength = new WorkoutSession();
        strength.setUser(user);
        strength.setStartedAt(Instant.now().minus(Duration.ofDays(1)));
        strength.setFinishedAt(Instant.now().minus(Duration.ofDays(1)).plus(Duration.ofMinutes(40)));
        workoutSessionRepository.save(strength);

        // A completed CARDIO session before `from` — must not contribute.
        saveCardioSession(user, Instant.now().minus(Duration.ofDays(10)), true, 12345.0);

        // A soft-deleted, completed CARDIO session in range — must not contribute.
        WorkoutSession deleted = new WorkoutSession();
        deleted.setUser(user);
        deleted.setStartedAt(Instant.now().minus(Duration.ofDays(4)));
        deleted.setFinishedAt(Instant.now().minus(Duration.ofDays(4)).plus(Duration.ofMinutes(30)));
        deleted.setSessionKind(SessionKind.CARDIO);
        deleted.setActivityType(ActivityType.RUNNING);
        deleted.setDeletedAt(Instant.now());
        workoutSessionRepository.save(deleted);
    }

    private void saveCardioSession(User user, Instant startedAt, boolean finished, double distanceMeters) {
        WorkoutSession session = new WorkoutSession();
        session.setUser(user);
        session.setStartedAt(startedAt);
        if (finished) {
            session.setFinishedAt(startedAt.plus(Duration.ofMinutes(30)));
        }
        session.setSessionKind(SessionKind.CARDIO);
        session.setActivityType(ActivityType.RUNNING);
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(session);
        details.setDistanceMeters(distanceMeters);
        session.setCardioDetails(details);
        workoutSessionRepository.save(session);
    }

    @Test
    void cardioCount_countsOnlyCompletedInRangeCardioSessions() {
        long cardioCount = workoutSessionRepository
                .countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThanAndFinishedAtIsNotNullAndSessionKind(
                        userId, from, toExclusive, SessionKind.CARDIO);
        long totalCompleted = workoutSessionRepository
                .countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThanAndFinishedAtIsNotNull(
                        userId, from, toExclusive);

        assertThat(cardioCount).isEqualTo(2);
        assertThat(totalCompleted).isEqualTo(3); // 2 cardio + 1 strength; the in-progress and pre-range rows don't count.
    }

    @Test
    void distance_sumsOnlyCompletedInRangeCardioSessions() {
        double distance = workoutSessionRepository.sumDistanceMetersBetweenForCompleted(userId, from, toExclusive);

        assertThat(distance).isEqualTo(4000.0 + 6000.0);
    }

    @Test
    void emptyWindow_coalescesToZeroInsteadOfNull() {
        Instant future = Instant.now().plus(Duration.ofDays(1));
        Instant furtherFuture = future.plus(Duration.ofDays(1));

        assertThat(workoutSessionRepository
                .countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThanAndFinishedAtIsNotNullAndSessionKind(
                        userId, future, furtherFuture, SessionKind.CARDIO))
                .isZero();
        assertThat(workoutSessionRepository.sumDistanceMetersBetweenForCompleted(userId, future, furtherFuture))
                .isZero();
    }
}
