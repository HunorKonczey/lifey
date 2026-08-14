package com.lifey.workout.session;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.session.cardio.ActivityType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.data.domain.PageRequest;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The {@code ?kind=} list filter's repository queries
 * (docs/cardio/52-cardio-domain-backend-plan.md §3.2 D-C1.3,
 * docs/cardio/59-cardio-implementation-plan.md C1.4) — derived Spring Data
 * query methods are exactly the kind of thing a mocked-repository unit test
 * (see WorkoutSessionServiceImplTest) can't catch a wrong property name or
 * join in, so this runs them against a real Postgres. Mirrors
 * UpcomingSessionRegressionTest's style: repository calls directly, no
 * service/auth layer needed.
 */
@SpringBootTest
@Testcontainers
class WorkoutSessionKindFilterRepositoryTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    WorkoutSessionRepository workoutSessionRepository;

    Long userId;

    @BeforeEach
    void seedOneStrengthAndOneCardioSession() {
        User user = new User();
        user.setEmail("kind-filter-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        userId = userRepository.save(user).getId();

        WorkoutSession strength = new WorkoutSession();
        strength.setUser(user);
        strength.setStartedAt(Instant.now().minus(java.time.Duration.ofHours(2)));
        // sessionKind defaults to STRENGTH — left unset, matching a real pre-cardio row.
        workoutSessionRepository.save(strength);

        WorkoutSession cardio = new WorkoutSession();
        cardio.setUser(user);
        cardio.setStartedAt(Instant.now().minus(java.time.Duration.ofHours(1)));
        cardio.setSessionKind(SessionKind.CARDIO);
        cardio.setActivityType(ActivityType.RUNNING);
        workoutSessionRepository.save(cardio);
    }

    @Test
    void unfilteredHistory_includesBothKinds() {
        List<WorkoutSession> all = workoutSessionRepository
                .findAllByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullOrderByStartedAtDesc(userId);

        assertThat(all).hasSize(2);
    }

    @Test
    void kindFilteredHistory_returnsOnlyThatKind() {
        List<WorkoutSession> cardioOnly = workoutSessionRepository
                .findAllByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullAndSessionKindOrderByStartedAtDesc(
                        userId, SessionKind.CARDIO);
        List<WorkoutSession> strengthOnly = workoutSessionRepository
                .findAllByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullAndSessionKindOrderByStartedAtDesc(
                        userId, SessionKind.STRENGTH);

        assertThat(cardioOnly).hasSize(1);
        assertThat(cardioOnly.getFirst().getActivityType()).isEqualTo(ActivityType.RUNNING);
        assertThat(strengthOnly).hasSize(1);
        assertThat(strengthOnly.getFirst().getSessionKind()).isEqualTo(SessionKind.STRENGTH);
    }

    @Test
    void pagedUnfilteredHistory_includesBothKinds() {
        var page = workoutSessionRepository.findByUserIdAndDeletedAtIsNullAndStartedAtIsNotNull(
                userId, PageRequest.of(0, 20));

        assertThat(page.getContent()).hasSize(2);
    }

    @Test
    void pagedKindFilteredHistory_returnsOnlyThatKind() {
        var cardioPage = workoutSessionRepository.findByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullAndSessionKind(
                userId, SessionKind.CARDIO, PageRequest.of(0, 20));

        assertThat(cardioPage.getContent()).hasSize(1);
        assertThat(cardioPage.getContent().getFirst().getSessionKind()).isEqualTo(SessionKind.CARDIO);
    }
}
