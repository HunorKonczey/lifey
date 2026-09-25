package com.lifey.workout.session;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.session.cardio.ActivityType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * {@code findFinishedStrengthSetsOldestFirst} — the query the trainer client
 * list replays to count personal records (docs/redesign/77-mobile-redesign-plan.md
 * R6.2). What matters is which sets it returns and in what order: only
 * finished, non-deleted strength sessions, oldest session first, each
 * session's sets in the order they were performed, and only the asked-for
 * user's.
 */
@SpringBootTest
@Testcontainers
class FinishedStrengthSetsQueryRepositoryTest {

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

    @BeforeEach
    void seedUsersAndAnExercise() {
        user = newUser("pr-query-" + System.nanoTime() + "@example.com");
        other = newUser("pr-query-other-" + System.nanoTime() + "@example.com");
        bench = new Exercise();
        bench.setUser(user);
        bench.setName("Bench press");
        exerciseRepository.save(bench);
    }

    @Test
    void returnsFinishedStrengthSetsOldestSessionFirstAndSetsInPerformedOrder() {
        Instant base = Instant.now().minus(10, ChronoUnit.DAYS).truncatedTo(ChronoUnit.MILLIS);
        // Saved newest-first on purpose: the ordering must come from the query, not from insertion.
        saveSession(user, base.plus(2, ChronoUnit.DAYS), SessionKind.STRENGTH, true, null,
                set(60, 5, base.plus(2, ChronoUnit.DAYS).plusSeconds(120)),
                set(55, 5, base.plus(2, ChronoUnit.DAYS).plusSeconds(60)));
        saveSession(user, base, SessionKind.STRENGTH, true, null,
                set(40, 8, base.plusSeconds(60)));

        List<ExerciseSet> sets = workoutSessionRepository.findFinishedStrengthSetsOldestFirst(user.getId());

        assertThat(sets).extracting(ExerciseSet::getWeight).containsExactly(40.0, 55.0, 60.0);
        // The session comes with the set, so the counter can read it without another query.
        assertThat(sets.getFirst().getWorkoutSession().getStartedAt()).isEqualTo(base);
    }

    @Test
    void leavesOutCardioUnfinishedDeletedAndOtherPeoplesSessions() {
        Instant started = Instant.now().minus(3, ChronoUnit.DAYS);
        saveSession(user, started, SessionKind.STRENGTH, true, null, set(50, 5, started.plusSeconds(60)));
        saveSession(user, started, SessionKind.CARDIO, true, null, set(99, 1, started.plusSeconds(60)));
        saveSession(user, started, SessionKind.STRENGTH, false, null, set(98, 1, started.plusSeconds(60)));
        saveSession(user, started, SessionKind.STRENGTH, true, Instant.now(), set(97, 1, started.plusSeconds(60)));
        saveSession(other, started, SessionKind.STRENGTH, true, null, set(96, 1, started.plusSeconds(60)));

        List<ExerciseSet> sets = workoutSessionRepository.findFinishedStrengthSetsOldestFirst(user.getId());

        assertThat(sets).extracting(ExerciseSet::getWeight).containsExactly(50.0);
    }

    @Test
    void aUserWithoutSetsGetsAnEmptyList() {
        assertThat(workoutSessionRepository.findFinishedStrengthSetsOldestFirst(other.getId())).isEmpty();
    }

    private User newUser(String email) {
        User u = new User();
        u.setEmail(email);
        u.setPasswordHash("irrelevant");
        u.setCreatedAt(Instant.now());
        u.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(u);
    }

    private record SetSpec(double weight, int reps, Instant performedAt) {
    }

    private static SetSpec set(double weight, int reps, Instant performedAt) {
        return new SetSpec(weight, reps, performedAt);
    }

    private void saveSession(User owner, Instant startedAt, SessionKind kind, boolean finished, Instant deletedAt,
                             SetSpec... specs) {
        WorkoutSession session = new WorkoutSession();
        session.setUser(owner);
        session.setStartedAt(startedAt);
        session.setFinishedAt(finished ? startedAt.plus(1, ChronoUnit.HOURS) : null);
        session.setSessionKind(kind);
        if (kind == SessionKind.CARDIO) {
            session.setActivityType(ActivityType.RUNNING);
        }
        session.setDeletedAt(deletedAt);
        for (SetSpec spec : specs) {
            ExerciseSet set = new ExerciseSet();
            set.setWorkoutSession(session);
            set.setExercise(bench);
            set.setWeight(spec.weight());
            set.setReps(spec.reps());
            set.setPerformedAt(spec.performedAt());
            session.getSets().add(set);
        }
        workoutSessionRepository.save(session);
    }
}
