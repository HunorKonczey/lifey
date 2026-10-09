package com.lifey.trainer;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.trainer.dto.TemplateUsageResponse;
import com.lifey.trainer.entity.ContentAssignment;
import com.lifey.trainer.entity.ProgramAssignment;
import com.lifey.trainer.entity.ProgramWorkout;
import com.lifey.trainer.entity.TrainingProgram;
import com.lifey.trainer.entity.WorkoutSchedule;
import com.lifey.trainer.service.TemplateUsageService;
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
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.time.LocalDate;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

/**
 * Which clients use which of a trainer's templates (LIF-106), against a real database: the three queries behind
 * {@code GET /trainer/templates/usage} - assignments, live schedules, and live program runs - and the rules that a
 * cancelled schedule, an ended schedule, an ended program and another trainer's rows do not count.
 */
@SpringBootTest
@Testcontainers
class TemplateUsageQueriesRegressionTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    TemplateUsageService usageService;

    @Autowired
    UserRepository userRepository;

    @Autowired
    WorkoutTemplateRepository templateRepository;

    @Autowired
    ContentAssignmentRepository contentAssignmentRepository;

    @Autowired
    WorkoutScheduleRepository scheduleRepository;

    @Autowired
    TrainingProgramRepository programRepository;

    @Autowired
    ProgramAssignmentRepository programAssignmentRepository;

    @MockitoBean
    CurrentUserProvider currentUserProvider;

    private User trainer;
    private User otherTrainer;
    private User assignedOnly;
    private User scheduled;
    private User cancelled;
    private User viaProgram;
    private User programEnded;
    private WorkoutTemplate template;
    private final LocalDate today = LocalDate.now();

    @BeforeEach
    void seed() {
        trainer = saveUser("usage-trainer");
        otherTrainer = saveUser("usage-other-trainer");
        assignedOnly = saveUser("usage-assigned");
        scheduled = saveUser("usage-scheduled");
        cancelled = saveUser("usage-cancelled");
        viaProgram = saveUser("usage-program");
        programEnded = saveUser("usage-program-ended");
        template = saveTemplate(trainer, "Push day");
        when(currentUserProvider.getUserId()).thenReturn(trainer.getId());
    }

    @Test
    void reportsAssignedAndScheduledClients_andOnlyTheLiveOnes() {
        assign(trainer, assignedOnly, template);
        assign(trainer, scheduled, template);
        assign(otherTrainer, assignedOnly, saveTemplate(otherTrainer, "Another trainer template"));

        schedule(trainer, scheduled, template, today.plusDays(10), null);
        schedule(trainer, cancelled, template, today.plusDays(10), Instant.now());
        schedule(trainer, assignedOnly, template, today.minusDays(1), null);

        TrainingProgram program = saveProgram(trainer);
        addProgramWorkout(program, template);
        runProgram(program, viaProgram, today.plusDays(20), null);
        runProgram(program, programEnded, today.minusDays(2), null);

        List<TemplateUsageResponse> usage = usageService.usageForCurrentTrainer();

        assertThat(usage).singleElement().satisfies(u -> {
            assertThat(u.templateId()).isEqualTo(template.getId());
            assertThat(u.assignedClientIds()).containsExactlyInAnyOrder(assignedOnly.getId(), scheduled.getId());
            // The live schedule and the running program count; the cancelled schedule, the schedule that ended and the
            // program that ended do not.
            assertThat(u.scheduledClientIds()).containsExactlyInAnyOrder(scheduled.getId(), viaProgram.getId());
        });
    }

    @Test
    void aTrainerWithNoUsageGetsAnEmptyList() {
        assertThat(usageService.usageForCurrentTrainer()).isEmpty();
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

    private WorkoutTemplate saveTemplate(User owner, String name) {
        WorkoutTemplate t = new WorkoutTemplate();
        t.setUser(owner);
        t.setName(name);
        return templateRepository.save(t);
    }

    private void assign(User trainerUser, User client, WorkoutTemplate source) {
        ContentAssignment a = new ContentAssignment();
        a.setTrainer(trainerUser);
        a.setClient(client);
        a.setContentType(ContentType.TEMPLATE);
        a.setSourceId(source.getId());
        a.setCopiedId(source.getId());
        a.setAssignedAt(Instant.now());
        contentAssignmentRepository.save(a);
    }

    private void schedule(User trainerUser, User client, WorkoutTemplate source, LocalDate endDate, Instant cancelledAt) {
        WorkoutSchedule s = new WorkoutSchedule();
        s.setTrainer(trainerUser);
        s.setClient(client);
        s.setSourceTemplateId(source.getId());
        s.setClientTemplate(source);
        s.setRecurrence(Recurrence.WEEKLY);
        s.setDaysOfWeek("MON");
        s.setStartDate(today.minusDays(30));
        s.setEndDate(endDate);
        s.setCreatedAt(Instant.now());
        s.setCancelledAt(cancelledAt);
        scheduleRepository.save(s);
    }

    private TrainingProgram saveProgram(User owner) {
        TrainingProgram p = new TrainingProgram();
        p.setUser(owner);
        p.setName("Program " + System.nanoTime());
        p.setWeeksCount(4);
        p.setCreatedAt(Instant.now());
        p.setUpdatedAt(Instant.now());
        return programRepository.save(p);
    }

    private void addProgramWorkout(TrainingProgram program, WorkoutTemplate t) {
        ProgramWorkout w = new ProgramWorkout();
        w.setProgram(program);
        w.setWeekNumber(1);
        w.setDayOfWeek("MON");
        w.setTemplate(t);
        program.getWorkouts().add(w);
        programRepository.save(program);
    }

    private void runProgram(TrainingProgram program, User client, LocalDate endDate, Instant cancelledAt) {
        ProgramAssignment pa = new ProgramAssignment();
        pa.setProgram(program);
        pa.setTrainer(trainer);
        pa.setClient(client);
        pa.setProgramName(program.getName());
        pa.setStartDate(today.minusDays(10));
        pa.setEndDate(endDate);
        pa.setAssignedAt(Instant.now());
        pa.setCancelledAt(cancelledAt);
        programAssignmentRepository.save(pa);
    }
}
