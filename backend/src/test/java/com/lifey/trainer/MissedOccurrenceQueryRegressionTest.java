package com.lifey.trainer;

import com.lifey.trainer.entity.TrainerClient;
import com.lifey.trainer.entity.WorkoutSchedule;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.session.WorkoutSession;
import com.lifey.workout.session.WorkoutSessionRepository;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateRepository;
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
import java.time.LocalDate;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The query behind the trainer's "a client missed a workout" push (LIF-100, docs/85-trainer-push-plan.md), against a real
 * database: which occurrences are candidates, for which trainer, and which are not - a started one, a deleted one, one already
 * announced, one of a cancelled schedule, one whose relationship is no longer active, one outside the date net.
 */
@SpringBootTest
@Testcontainers
@Transactional
class MissedOccurrenceQueryRegressionTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    WorkoutTemplateRepository templateRepository;

    @Autowired
    WorkoutScheduleRepository scheduleRepository;

    @Autowired
    WorkoutSessionRepository sessionRepository;

    @Autowired
    TrainerClientRepository trainerClientRepository;

    private final LocalDate today = LocalDate.now();
    private User trainer;
    private User client;
    private WorkoutSchedule schedule;

    @BeforeEach
    void seed() {
        trainer = saveUser("missed-trainer");
        client = saveUser("missed-client");
        client.setFirstName("Anna");
        client.setLastName("Kovacs");
        trainer.setUtcOffsetMinutes(120);
        relationship(trainer, client, TrainerClientStatus.ACTIVE);
        schedule = schedule(trainer, client, null);
    }

    @Test
    void aMissedOccurrenceIsACandidate_withTheTrainerAndTheClientItBelongsTo() {
        WorkoutSession missed = occurrence(client, schedule, today.minusDays(1), "Push day");

        List<MissedOccurrence> candidates = candidates();

        assertThat(candidates).singleElement().satisfies(c -> {
            assertThat(c.sessionId()).isEqualTo(missed.getId());
            assertThat(c.scheduledFor()).isEqualTo(today.minusDays(1));
            assertThat(c.workoutName()).isEqualTo("Push day");
            assertThat(c.trainerId()).isEqualTo(trainer.getId());
            assertThat(c.trainerUtcOffsetMinutes()).isEqualTo(120);
            assertThat(c.clientId()).isEqualTo(client.getId());
            assertThat(c.clientDisplayName()).isEqualTo("Anna Kovacs");
        });
    }

    @Test
    void whatIsNotMissedOrAlreadyHandledIsNotACandidate() {
        WorkoutSession started = occurrence(client, schedule, today.minusDays(1), "Started");
        started.setStartedAt(Instant.now());
        WorkoutSession deleted = occurrence(client, schedule, today.minusDays(1), "Deleted");
        deleted.setDeletedAt(Instant.now());
        WorkoutSession announced = occurrence(client, schedule, today.minusDays(1), "Announced");
        announced.setMissedNotifiedAt(Instant.now());
        occurrence(client, schedule, today.minusDays(30), "Too old for the net");
        occurrence(client, schedule, today.plusDays(10), "Too far ahead for the net");
        // Not trainer-scheduled: no schedule id.
        WorkoutSession own = occurrence(client, schedule, today.minusDays(1), "Own");
        own.setScheduleId(null);
        sessionRepository.flush();

        assertThat(candidates()).isEmpty();
    }

    @Test
    void aCancelledScheduleAndARevokedRelationshipAreNotAnnounced() {
        WorkoutSchedule cancelled = schedule(trainer, client, Instant.now());
        occurrence(client, cancelled, today.minusDays(1), "Cancelled schedule");

        User other = saveUser("missed-revoked-client");
        relationship(trainer, other, TrainerClientStatus.REVOKED);
        occurrence(other, schedule(trainer, other, null), today.minusDays(1), "Revoked");

        assertThat(candidates()).isEmpty();
    }

    @Test
    void eachTrainerOfAClientIsToldOnlyAboutTheirOwnSchedule() {
        User otherTrainer = saveUser("missed-other-trainer");
        relationship(otherTrainer, client, TrainerClientStatus.ACTIVE);
        WorkoutSession mine = occurrence(client, schedule, today.minusDays(1), "Mine");
        WorkoutSession theirs = occurrence(client, schedule(otherTrainer, client, null), today.minusDays(1), "Theirs");

        List<MissedOccurrence> candidates = candidates();

        assertThat(candidates).extracting(MissedOccurrence::sessionId).containsExactlyInAnyOrder(mine.getId(), theirs.getId());
        assertThat(candidates).filteredOn(c -> c.sessionId().equals(mine.getId()))
                .singleElement().extracting(MissedOccurrence::trainerId).isEqualTo(trainer.getId());
        assertThat(candidates).filteredOn(c -> c.sessionId().equals(theirs.getId()))
                .singleElement().extracting(MissedOccurrence::trainerId).isEqualTo(otherTrainer.getId());
    }

    @Test
    void markingAnOccurrenceAnnouncedTakesItOutOfTheCandidates() {
        WorkoutSession first = occurrence(client, schedule, today.minusDays(1), "First");
        occurrence(client, schedule, today.minusDays(2), "Second");

        sessionRepository.markMissedNotified(List.of(first.getId()), Instant.now());
        sessionRepository.flush();
        // The bulk update bypasses the persistence context, so what is read below is what the database holds.
        assertThat(candidates()).extracting(MissedOccurrence::workoutName).containsExactly("Second");
    }

    private List<MissedOccurrence> candidates() {
        return scheduleRepository.findMissedOccurrenceCandidates(today.minusDays(5), today.plusDays(1));
    }

    // ---- seed helpers ----

    private User saveUser(String prefix) {
        User user = new User();
        user.setEmail(prefix + "-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(user);
    }

    private void relationship(User trainerUser, User clientUser, TrainerClientStatus status) {
        TrainerClient tc = new TrainerClient();
        tc.setTrainer(trainerUser);
        tc.setClient(clientUser);
        tc.setStatus(status);
        tc.setCreatedAt(Instant.now());
        tc.setExpiresAt(Instant.now().plusSeconds(3600));
        trainerClientRepository.save(tc);
    }

    private WorkoutSchedule schedule(User trainerUser, User clientUser, Instant cancelledAt) {
        WorkoutTemplate template = new WorkoutTemplate();
        template.setUser(clientUser);
        template.setName("Template " + System.nanoTime());
        template = templateRepository.save(template);
        WorkoutSchedule s = new WorkoutSchedule();
        s.setTrainer(trainerUser);
        s.setClient(clientUser);
        s.setSourceTemplateId(template.getId());
        s.setClientTemplate(template);
        s.setRecurrence(Recurrence.WEEKLY);
        s.setDaysOfWeek("MON");
        s.setStartDate(today.minusDays(30));
        s.setEndDate(today.plusDays(30));
        s.setCreatedAt(Instant.now());
        s.setCancelledAt(cancelledAt);
        return scheduleRepository.save(s);
    }

    private WorkoutSession occurrence(User owner, WorkoutSchedule fromSchedule, LocalDate day, String name) {
        WorkoutSession session = new WorkoutSession();
        session.setUser(owner);
        session.setScheduleId(fromSchedule.getId());
        session.setScheduledFor(day);
        session.setTemplateName(name);
        return sessionRepository.save(session);
    }
}
