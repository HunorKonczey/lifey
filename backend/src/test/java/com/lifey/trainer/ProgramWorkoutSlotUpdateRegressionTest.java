package com.lifey.trainer;

import com.lifey.trainer.entity.ProgramWorkout;
import com.lifey.trainer.entity.TrainingProgram;
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
import org.springframework.transaction.annotation.Transactional;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Regression test for the {@code program_workouts_slot_unique} constraint
 * (program_id, week_number, day_of_week) interacting with Hibernate's default
 * flush order (all entity insertions before all entity deletions in the same
 * flush). {@link com.lifey.trainer.service.TrainingProgramServiceImpl#update}
 * does a clear-and-re-add full replace of a program's slots
 * (docs/34-multi-week-program-plan.md) — re-saving the same (week, day) slot
 * unchanged used to insert the new row before the orphaned old row was
 * deleted, tripping the unique constraint with a spurious 409. Fixed by an
 * explicit flush between the clear and the re-add.
 */
@SpringBootTest
@Testcontainers
class ProgramWorkoutSlotUpdateRegressionTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    WorkoutTemplateRepository workoutTemplateRepository;

    @Autowired
    TrainingProgramRepository trainingProgramRepository;

    Long trainerId;
    WorkoutTemplate template;

    @BeforeEach
    void seedTrainerAndTemplate() {
        trainerId = saveUser("program-slot-update-trainer-" + System.nanoTime() + "@example.com").getId();

        template = new WorkoutTemplate();
        template.setUser(userRepository.getReferenceById(trainerId));
        template.setName("Program-slot-update regression template");
        template = workoutTemplateRepository.save(template);
    }

    /**
     * Mirrors {@code TrainingProgramServiceImpl.update}: clear the collection,
     * flush, then re-add a slot at the exact same (week, day) — the case that
     * used to violate the unique constraint without the fix's explicit flush.
     */
    @Test
    @Transactional
    void resavingTheSameSlotDoesNotViolateTheUniqueConstraint() {
        TrainingProgram program = new TrainingProgram();
        program.setUser(userRepository.getReferenceById(trainerId));
        program.setName("Regression Block");
        program.setWeeksCount(1);
        program.setCreatedAt(Instant.now());
        program.setUpdatedAt(Instant.now());
        program.getWorkouts().add(slot(program, 1, "MON"));
        program = trainingProgramRepository.saveAndFlush(program);

        program.getWorkouts().clear();
        trainingProgramRepository.flush();
        program.getWorkouts().add(slot(program, 1, "MON"));

        trainingProgramRepository.saveAndFlush(program);

        List<ProgramWorkout> reloaded = trainingProgramRepository.findById(program.getId())
                .orElseThrow().getWorkouts();
        assertThat(reloaded).hasSize(1);
        assertThat(reloaded.getFirst().getWeekNumber()).isEqualTo(1);
        assertThat(reloaded.getFirst().getDayOfWeek()).isEqualTo("MON");
    }

    private ProgramWorkout slot(TrainingProgram program, int week, String day) {
        ProgramWorkout workout = new ProgramWorkout();
        workout.setProgram(program);
        workout.setWeekNumber(week);
        workout.setDayOfWeek(day);
        workout.setTemplate(template);
        return workout;
    }

    private User saveUser(String email) {
        User user = new User();
        user.setEmail(email);
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(user);
    }
}
