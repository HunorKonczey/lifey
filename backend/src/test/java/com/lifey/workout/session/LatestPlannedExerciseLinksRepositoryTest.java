package com.lifey.workout.session;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.transaction.annotation.Transactional;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * {@code findLatestPlannedExerciseLinks} — where a session started on the web
 * carries each exercise's comment over from (LIF-225). Newest started session
 * first; deleted, not-yet-started, excluded and other people's sessions left out.
 */
@SpringBootTest
@Testcontainers
@Transactional
class LatestPlannedExerciseLinksRepositoryTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    ExerciseRepository exerciseRepository;

    @Autowired
    WorkoutSessionRepository workoutSessionRepository;

    User user;
    User other;
    Exercise bench;
    Exercise row;

    @BeforeEach
    void seed() {
        user = newUser("note-links-" + System.nanoTime() + "@example.com");
        other = newUser("note-links-other-" + System.nanoTime() + "@example.com");
        bench = newExercise(user, "Bench press");
        row = newExercise(user, "Row");
    }

    @Test
    void returnsTheLinksNewestSessionFirst() {
        Instant base = Instant.now().minus(10, ChronoUnit.DAYS);
        saveSession(user, base.plus(1, ChronoUnit.DAYS), null, bench, "seat on 3");
        saveSession(user, base.plus(5, ChronoUnit.DAYS), null, bench, "seat on 4");
        saveSession(user, base.plus(3, ChronoUnit.DAYS), null, row, "grip wide");

        List<WorkoutSessionExercise> links = workoutSessionRepository.findLatestPlannedExerciseLinks(
                user.getId(), List.of(bench.getId(), row.getId()), -1L);

        assertThat(links).extracting(WorkoutSessionExercise::getNote)
                .containsExactly("seat on 4", "grip wide", "seat on 3");
    }

    @Test
    void leavesOutDeletedUpcomingExcludedAndOtherPeoplesSessions() {
        Instant started = Instant.now().minus(3, ChronoUnit.DAYS);
        saveSession(user, started, null, bench, "kept");
        saveSession(user, started.plusSeconds(60), Instant.now(), bench, "deleted");
        saveSession(user, null, null, bench, "upcoming");
        WorkoutSession excluded = saveSession(user, started.plusSeconds(120), null, bench, "excluded");
        Exercise othersBench = newExercise(other, "Bench press");
        saveSession(other, started.plusSeconds(180), null, othersBench, "someone else");

        List<WorkoutSessionExercise> links = workoutSessionRepository.findLatestPlannedExerciseLinks(
                user.getId(), List.of(bench.getId(), othersBench.getId()), excluded.getId());

        assertThat(links).extracting(WorkoutSessionExercise::getNote).containsExactly("kept");
    }

    private User newUser(String email) {
        User u = new User();
        u.setEmail(email);
        u.setPasswordHash("irrelevant");
        u.setCreatedAt(Instant.now());
        u.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(u);
    }

    private Exercise newExercise(User owner, String name) {
        Exercise e = new Exercise();
        e.setUser(owner);
        e.setName(name);
        return exerciseRepository.save(e);
    }

    private WorkoutSession saveSession(User owner, Instant startedAt, Instant deletedAt, Exercise exercise, String note) {
        WorkoutSession session = new WorkoutSession();
        session.setUser(owner);
        session.setStartedAt(startedAt);
        if (startedAt == null) {
            session.setScheduledFor(java.time.LocalDate.now().plusDays(3));
        }
        session.setSessionKind(SessionKind.STRENGTH);
        session.setDeletedAt(deletedAt);
        WorkoutSessionExercise link = new WorkoutSessionExercise();
        link.setWorkoutSession(session);
        link.setExercise(exercise);
        link.setNote(note);
        session.getPlannedExercises().add(link);
        return workoutSessionRepository.save(session);
    }
}
