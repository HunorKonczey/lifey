package com.lifey.workout.session;

import com.lifey.trainer.Recurrence;
import com.lifey.trainer.entity.WorkoutSchedule;
import com.lifey.trainer.WorkoutScheduleRepository;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Instant;
import java.time.LocalDate;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Regression test for {@link WorkoutSessionRepository#countMissedOccurrences} — the
 * trainer compliance overview's missed-workout count (docs/29-compliance-overview-plan.md,
 * B2). Must agree with the MISSED branch of
 * com.lifey.trainer.service.WorkoutScheduleServiceImpl#occurrenceStatus().
 */
@SpringBootTest
@Testcontainers
class MissedOccurrenceCountRegressionTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    WorkoutTemplateRepository workoutTemplateRepository;

    @Autowired
    WorkoutScheduleRepository workoutScheduleRepository;

    @Autowired
    WorkoutSessionRepository workoutSessionRepository;

    Long trainerId;
    Long otherTrainerId;
    Long clientId;
    LocalDate today;

    @BeforeEach
    void seedTrainerScheduleAndOccurrences() {
        trainerId = saveUser("missed-count-trainer-" + System.nanoTime() + "@example.com").getId();
        otherTrainerId = saveUser("missed-count-other-trainer-" + System.nanoTime() + "@example.com").getId();
        User client = saveUser("missed-count-client-" + System.nanoTime() + "@example.com");
        clientId = client.getId();
        today = LocalDate.now();

        WorkoutSchedule mySchedule = saveSchedule(trainerId, client);
        WorkoutSchedule otherTrainerSchedule = saveSchedule(otherTrainerId, client);

        // In-window miss under this trainer — should count.
        saveOccurrence(client, mySchedule.getId(), today.minusDays(3), null, null);
        // Started (not missed) — must not count.
        saveOccurrence(client, mySchedule.getId(), today.minusDays(2), Instant.now(), null);
        // Cancelled (soft-deleted) — must not count.
        saveOccurrence(client, mySchedule.getId(), today.minusDays(1), null, Instant.now());
        // Outside the 14-day window — must not count.
        saveOccurrence(client, mySchedule.getId(), today.minusDays(20), null, null);
        // Upcoming (not yet due) — must not count.
        saveOccurrence(client, mySchedule.getId(), today.plusDays(1), null, null);
        // Missed, but under a different trainer's schedule — must not count.
        saveOccurrence(client, otherTrainerSchedule.getId(), today.minusDays(3), null, null);
    }

    @Test
    void countsOnlyInWindowMissedOccurrencesForThisTrainer() {
        long count = workoutSessionRepository.countMissedOccurrences(
                trainerId, clientId, today.minusDays(14), today);

        assertThat(count).isEqualTo(1);
    }

    private User saveUser(String email) {
        User user = new User();
        user.setEmail(email);
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(user);
    }

    private WorkoutSchedule saveSchedule(Long trainerId, User client) {
        WorkoutTemplate template = new WorkoutTemplate();
        template.setUser(client);
        template.setName("Missed-count regression template");
        template = workoutTemplateRepository.save(template);

        WorkoutSchedule schedule = new WorkoutSchedule();
        schedule.setTrainer(userRepository.getReferenceById(trainerId));
        schedule.setClient(client);
        schedule.setSourceTemplateId(template.getId());
        schedule.setClientTemplate(template);
        schedule.setRecurrence(Recurrence.WEEKLY);
        schedule.setDaysOfWeek("MON");
        schedule.setStartDate(today.minusDays(30));
        schedule.setEndDate(today.plusDays(30));
        schedule.setCreatedAt(Instant.now());
        return workoutScheduleRepository.save(schedule);
    }

    private void saveOccurrence(User client, Long scheduleId, LocalDate scheduledFor, Instant startedAt, Instant deletedAt) {
        WorkoutSession occurrence = new WorkoutSession();
        occurrence.setUser(client);
        occurrence.setScheduleId(scheduleId);
        occurrence.setScheduledFor(scheduledFor);
        occurrence.setStartedAt(startedAt);
        occurrence.setDeletedAt(deletedAt);
        workoutSessionRepository.save(occurrence);
    }
}
