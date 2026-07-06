package com.lifey.workout.session;

import com.lifey.statistics.dto.StatisticsResponse;
import com.lifey.statistics.service.StatisticsService;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.data.domain.PageRequest;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Regression test for docs/personal_trainer/09-utemezett-edzesek-domain-backend.md,
 * "Elvégzett = started_at not null": once trainer-scheduled (upcoming) sessions
 * exist — {@code startedAt} null, {@code scheduledFor} set — every path that
 * treats a session as a "workout that happened" must keep excluding them, while
 * the delta-sync feed must keep including them (the mobile client needs to see
 * upcoming sessions to render the "Közelgő" list and the pop-up card).
 */
@SpringBootTest
@Testcontainers
class UpcomingSessionRegressionTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    WorkoutSessionRepository workoutSessionRepository;

    @Autowired
    StatisticsService statisticsService;

    Long userId;

    @BeforeEach
    void seedUserWithOneHappenedAndOneUpcomingSession() {
        User user = new User();
        user.setEmail("upcoming-session-regression-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        userId = userRepository.save(user).getId();

        WorkoutSession happened = new WorkoutSession();
        happened.setUser(user);
        happened.setStartedAt(Instant.now().minus(1, ChronoUnit.DAYS));
        workoutSessionRepository.save(happened);

        WorkoutSession upcoming = new WorkoutSession();
        upcoming.setUser(user);
        upcoming.setScheduledFor(LocalDate.now().plusDays(2));
        workoutSessionRepository.save(upcoming);
    }

    @Test
    void statistics_excludesUpcomingSession() {
        StatisticsResponse stats = statisticsService.weeklyForUser(userId, LocalDate.now());

        assertThat(stats.workoutCount()).isEqualTo(1);
    }

    @Test
    void unpagedHistory_excludesUpcomingSession() {
        List<WorkoutSession> history = workoutSessionRepository
                .findAllByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullOrderByStartedAtDesc(userId);

        assertThat(history).hasSize(1);
        assertThat(history.getFirst().getStartedAt()).isNotNull();
    }

    @Test
    void pagedHistory_excludesUpcomingSession() {
        var page = workoutSessionRepository.findByUserIdAndDeletedAtIsNullAndStartedAtIsNotNull(
                userId, PageRequest.of(0, 20));

        assertThat(page.getContent()).hasSize(1);
        assertThat(page.getContent().getFirst().getStartedAt()).isNotNull();
    }

    @Test
    void deltaSync_includesUpcomingSession() {
        var page = workoutSessionRepository.findByUserIdAndUpdatedAtGreaterThanEqual(
                userId, Instant.now().minus(1, ChronoUnit.HOURS), PageRequest.of(0, 20));

        assertThat(page.getContent()).hasSize(2);
    }
}
