package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.trainer.ProgramAssignmentRepository;
import com.lifey.trainer.TrainingProgramRepository;
import com.lifey.trainer.dto.ProgramRequest;
import com.lifey.trainer.dto.ProgramResponse;
import com.lifey.trainer.dto.ProgramSummaryResponse;
import com.lifey.trainer.dto.ProgramWorkoutRequest;
import com.lifey.trainer.entity.ProgramWorkout;
import com.lifey.trainer.entity.TrainingProgram;
import com.lifey.trainer.exception.InvalidProgramStructureException;
import com.lifey.trainer.exception.ProgramNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TrainingProgramServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long TEMPLATE_ID = 7L;
    private static final Long PROGRAM_ID = 5L;

    @Mock
    TrainingProgramRepository trainingProgramRepository;

    @Mock
    ProgramAssignmentRepository programAssignmentRepository;

    @Mock
    WorkoutTemplateRepository workoutTemplateRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    TrainingProgramServiceImpl service;

    WorkoutTemplate template;

    @BeforeEach
    void stubCommon() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);

        template = new WorkoutTemplate();
        template.setId(TEMPLATE_ID);
        template.setName("Push day");
        lenient().when(workoutTemplateRepository.findByIdAndUserIdAndDeletedAtIsNull(TEMPLATE_ID, TRAINER_ID))
                .thenReturn(Optional.of(template));

        User trainer = new User();
        trainer.setId(TRAINER_ID);
        lenient().when(userRepository.getReferenceById(TRAINER_ID)).thenReturn(trainer);

        lenient().when(trainingProgramRepository.save(any(TrainingProgram.class)))
                .thenAnswer(invocation -> {
                    TrainingProgram program = invocation.getArgument(0);
                    program.setId(PROGRAM_ID);
                    return program;
                });
    }

    private ProgramWorkoutRequest slot(int week, DayOfWeek day) {
        return new ProgramWorkoutRequest(week, day, TEMPLATE_ID, null, null);
    }

    @Test
    void create_buildsGridAndReturnsResolvedTemplateNames() {
        ProgramRequest request = new ProgramRequest("Hypertrophy Block", 2,
                List.of(slot(1, DayOfWeek.MONDAY), slot(1, DayOfWeek.THURSDAY), slot(2, DayOfWeek.MONDAY)));

        ProgramResponse response = service.create(request);

        assertThat(response.id()).isEqualTo(PROGRAM_ID);
        assertThat(response.name()).isEqualTo("Hypertrophy Block");
        assertThat(response.weeksCount()).isEqualTo(2);
        assertThat(response.workouts()).hasSize(3);
        assertThat(response.workouts().get(0).templateName()).isEqualTo("Push day");
        // sorted by week, then day
        assertThat(response.workouts()).extracting(w -> w.weekNumber() + ":" + w.dayOfWeek())
                .containsExactly("1:MONDAY", "1:THURSDAY", "2:MONDAY");
    }

    @Test
    void create_rejectsSlotWeekBeyondWeeksCount() {
        ProgramRequest request = new ProgramRequest("Bad", 1, List.of(slot(2, DayOfWeek.MONDAY)));

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(InvalidProgramStructureException.class);
    }

    @Test
    void create_rejectsDuplicateSlot() {
        ProgramRequest request = new ProgramRequest("Bad", 1,
                List.of(slot(1, DayOfWeek.MONDAY), slot(1, DayOfWeek.MONDAY)));

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(InvalidProgramStructureException.class);
    }

    @Test
    void create_rejectsTemplateNotOwnedByTrainer() {
        when(workoutTemplateRepository.findByIdAndUserIdAndDeletedAtIsNull(99L, TRAINER_ID))
                .thenReturn(Optional.empty());
        ProgramRequest request = new ProgramRequest("Bad", 1, List.of(
                new ProgramWorkoutRequest(1, DayOfWeek.MONDAY, 99L, null, null)));

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(InvalidProgramStructureException.class);
    }

    @Test
    void findAll_computesSlotsPerWeekAndActiveAssignmentCount() {
        TrainingProgram program = new TrainingProgram();
        program.setId(PROGRAM_ID);
        program.setName("Block");
        program.setWeeksCount(2);
        program.getWorkouts().add(workoutSlot(program, 1, "MON"));
        program.getWorkouts().add(workoutSlot(program, 1, "THU"));
        program.getWorkouts().add(workoutSlot(program, 2, "MON"));

        when(trainingProgramRepository.findByUserIdAndDeletedAtIsNullOrderByCreatedAtDesc(TRAINER_ID))
                .thenReturn(List.of(program));
        when(programAssignmentRepository.countByProgramIdAndCancelledAtIsNullAndEndDateGreaterThanEqual(
                eq(PROGRAM_ID), any(LocalDate.class))).thenReturn(3);

        List<ProgramSummaryResponse> summaries = service.findAll();

        assertThat(summaries).hasSize(1);
        ProgramSummaryResponse summary = summaries.get(0);
        assertThat(summary.slotsPerWeek()).isEqualTo(2); // distinct days: MON, THU
        assertThat(summary.activeAssignmentCount()).isEqualTo(3);
    }

    private ProgramWorkout workoutSlot(TrainingProgram program, int week, String day) {
        ProgramWorkout workout = new ProgramWorkout();
        workout.setProgram(program);
        workout.setWeekNumber(week);
        workout.setDayOfWeek(day);
        workout.setTemplate(template);
        return workout;
    }

    @Test
    void update_fullyReplacesSlotsAndDoesNotTouchAssignments() {
        TrainingProgram existing = new TrainingProgram();
        existing.setId(PROGRAM_ID);
        existing.setName("Old");
        existing.setWeeksCount(1);
        when(trainingProgramRepository.findByIdAndUserIdAndDeletedAtIsNull(PROGRAM_ID, TRAINER_ID))
                .thenReturn(Optional.of(existing));

        ProgramRequest request = new ProgramRequest("New name", 2,
                List.of(slot(1, DayOfWeek.TUESDAY), slot(2, DayOfWeek.FRIDAY)));

        ProgramResponse response = service.update(PROGRAM_ID, request);

        assertThat(response.name()).isEqualTo("New name");
        assertThat(response.weeksCount()).isEqualTo(2);
        assertThat(response.workouts()).hasSize(2);
    }

    @Test
    void update_unknownProgram_throwsNotFound() {
        when(trainingProgramRepository.findByIdAndUserIdAndDeletedAtIsNull(anyLong(), anyLong()))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.update(PROGRAM_ID, new ProgramRequest("X", 1, List.of(slot(1, DayOfWeek.MONDAY)))))
                .isInstanceOf(ProgramNotFoundException.class);
    }

    @Test
    void delete_softDeletesOwnedProgram() {
        TrainingProgram existing = new TrainingProgram();
        existing.setId(PROGRAM_ID);
        when(trainingProgramRepository.findByIdAndUserIdAndDeletedAtIsNull(PROGRAM_ID, TRAINER_ID))
                .thenReturn(Optional.of(existing));

        service.delete(PROGRAM_ID);

        assertThat(existing.getDeletedAt()).isNotNull();
    }

    @Test
    void delete_unknownProgram_throwsNotFound() {
        when(trainingProgramRepository.findByIdAndUserIdAndDeletedAtIsNull(anyLong(), anyLong()))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(PROGRAM_ID)).isInstanceOf(ProgramNotFoundException.class);
    }
}
