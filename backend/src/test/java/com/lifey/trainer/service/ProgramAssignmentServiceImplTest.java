package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.trainer.ProgramAssignmentRepository;
import com.lifey.trainer.TrainingProgramRepository;
import com.lifey.trainer.dto.ProgramAssignmentRequest;
import com.lifey.trainer.dto.ProgramAssignmentResponse;
import com.lifey.trainer.entity.ProgramAssignment;
import com.lifey.trainer.entity.ProgramWorkout;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.trainer.entity.TrainingProgram;
import com.lifey.trainer.exception.InvalidProgramStructureException;
import com.lifey.trainer.exception.ProgramAssignmentNotFoundException;
import com.lifey.trainer.exception.ProgramNotFoundException;
import com.lifey.trainer.exception.ProgramStartDateInvalidException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.session.WorkoutSession;
import com.lifey.workout.session.WorkoutSessionRepository;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
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
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ProgramAssignmentServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;
    private static final Long TEMPLATE_ID = 7L;
    private static final Long PROGRAM_ID = 5L;
    private static final Long ASSIGNMENT_ID = 9L;

    @Mock
    ProgramAssignmentRepository programAssignmentRepository;

    @Mock
    TrainingProgramRepository trainingProgramRepository;

    @Mock
    WorkoutTemplateRepository workoutTemplateRepository;

    @Mock
    WorkoutSessionRepository workoutSessionRepository;

    @Mock
    ContentAssignmentService contentAssignmentService;

    @Mock
    TrainerAccessService trainerAccessService;

    @Mock
    UserRepository userRepository;

    @Mock
    UserSettingsRepository userSettingsRepository;

    @Mock
    PushService pushService;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    ProgramAssignmentServiceImpl service;

    WorkoutTemplate sourceTemplate;
    WorkoutTemplate clientTemplate;
    TrainingProgram program;

    @BeforeEach
    void stubCommon() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
        lenient().when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());

        sourceTemplate = new WorkoutTemplate();
        sourceTemplate.setId(TEMPLATE_ID);
        sourceTemplate.setName("Push day");
        lenient().when(workoutTemplateRepository.findByIdAndUserIdAndDeletedAtIsNull(TEMPLATE_ID, TRAINER_ID))
                .thenReturn(Optional.of(sourceTemplate));

        clientTemplate = new WorkoutTemplate();
        clientTemplate.setId(55L);
        clientTemplate.setName("Push day");
        lenient().when(contentAssignmentService.resolveClientCopy(TRAINER_ID, CLIENT_ID, sourceTemplate))
                .thenReturn(clientTemplate);

        User trainer = new User();
        trainer.setId(TRAINER_ID);
        User client = new User();
        client.setId(CLIENT_ID);
        lenient().when(userRepository.getReferenceById(TRAINER_ID)).thenReturn(trainer);
        lenient().when(userRepository.getReferenceById(CLIENT_ID)).thenReturn(client);

        program = new TrainingProgram();
        program.setId(PROGRAM_ID);
        program.setName("Hypertrophy Block");
        program.setWeeksCount(2);
        program.getWorkouts().add(slot(1, "MON"));
        program.getWorkouts().add(slot(2, "THU"));
        lenient().when(trainingProgramRepository.findByIdAndUserIdAndDeletedAtIsNull(PROGRAM_ID, TRAINER_ID))
                .thenReturn(Optional.of(program));

        lenient().when(programAssignmentRepository.save(any(ProgramAssignment.class))).thenAnswer(inv -> {
            ProgramAssignment a = inv.getArgument(0);
            a.setId(ASSIGNMENT_ID);
            return a;
        });
    }

    private ProgramWorkout slot(int week, String day) {
        ProgramWorkout workout = new ProgramWorkout();
        workout.setProgram(program);
        workout.setWeekNumber(week);
        workout.setDayOfWeek(day);
        workout.setTemplate(sourceTemplate);
        return workout;
    }

    /** 2026-07-13 is a Monday. */
    private static final LocalDate A_MONDAY = LocalDate.of(2026, 7, 13);

    @Test
    void assign_materializesOneOccurrencePerSlotOnCorrectDates() {
        ProgramAssignmentResponse response = service.assign(PROGRAM_ID, new ProgramAssignmentRequest(CLIENT_ID, A_MONDAY));

        assertThat(response.assignmentId()).isEqualTo(ASSIGNMENT_ID);
        assertThat(response.occurrenceCount()).isEqualTo(2);
        assertThat(response.startDate()).isEqualTo(A_MONDAY);
        assertThat(response.endDate()).isEqualTo(A_MONDAY.plusWeeks(2).minusDays(1));

        ArgumentCaptor<WorkoutSession> captor = ArgumentCaptor.forClass(WorkoutSession.class);
        verify(workoutSessionRepository, org.mockito.Mockito.times(2)).save(captor.capture());
        List<WorkoutSession> saved = captor.getAllValues();
        assertThat(saved).allSatisfy(s -> {
            assertThat(s.getProgramAssignmentId()).isEqualTo(ASSIGNMENT_ID);
            assertThat(s.getTemplateName()).isEqualTo("Push day");
        });
        // week 1 MON = start date itself; week 2 THU = start + 1 week + 3 days
        assertThat(saved).extracting(WorkoutSession::getScheduledFor)
                .containsExactlyInAnyOrder(A_MONDAY, A_MONDAY.plusWeeks(1).plusDays(3));
    }

    @Test
    void assign_sendsPushWithFirstOccurrenceDateAndAssignmentId() {
        service.assign(PROGRAM_ID, new ProgramAssignmentRequest(CLIENT_ID, A_MONDAY));

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(CLIENT_ID), captor.capture());
        PushMessage message = captor.getValue();
        assertThat(message.title()).isEqualTo("Your trainer started you on a program");
        // earliest slot is week 1 MON = A_MONDAY itself
        assertThat(message.body()).contains("Hypertrophy Block").contains("Mon, Jul 13");
        assertThat(message.data()).containsEntry("type", "program_assigned")
                .containsEntry("programAssignmentId", String.valueOf(ASSIGNMENT_ID));
    }

    @Test
    void assign_skipsPushWhenProgramAssignedPushDisabled() {
        UserSettings settingsRow = new UserSettings();
        settingsRow.setProgramAssignedPushEnabled(false);
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.of(settingsRow));

        service.assign(PROGRAM_ID, new ProgramAssignmentRequest(CLIENT_ID, A_MONDAY));

        verify(pushService, never()).sendToUser(any(), any());
    }

    @Test
    void assign_sendsPushWithHungarianCopyWhenClientPrefersHungarian() {
        UserSettings settingsRow = new UserSettings();
        settingsRow.setLanguage(LanguagePreference.HUNGARIAN);
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.of(settingsRow));

        service.assign(PROGRAM_ID, new ProgramAssignmentRequest(CLIENT_ID, A_MONDAY));

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(CLIENT_ID), captor.capture());
        assertThat(captor.getValue().title()).isEqualTo("Az edződ elindított egy programot");
    }

    @Test
    void assign_pushUsesEarliestSlotDate_evenWhenNotOnTheStartDateItself() {
        // Replace the default MON/THU grid with a program whose first slot is week 1 WED —
        // the push's "first session" date must reflect that, not the assignment's Monday startDate.
        program.getWorkouts().clear();
        program.getWorkouts().add(slot(1, "WED"));
        program.getWorkouts().add(slot(1, "FRI"));

        service.assign(PROGRAM_ID, new ProgramAssignmentRequest(CLIENT_ID, A_MONDAY));

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(CLIENT_ID), captor.capture());
        assertThat(captor.getValue().body()).contains("Wed, Jul 15");
    }

    @Test
    void assign_nonMondayStart_throws() {
        assertThatThrownBy(() -> service.assign(PROGRAM_ID, new ProgramAssignmentRequest(CLIENT_ID, A_MONDAY.plusDays(1))))
                .isInstanceOf(ProgramStartDateInvalidException.class);
    }

    @Test
    void assign_pastStart_throws() {
        assertThatThrownBy(() -> service.assign(PROGRAM_ID, new ProgramAssignmentRequest(CLIENT_ID, LocalDate.of(2020, 1, 6))))
                .isInstanceOf(ProgramStartDateInvalidException.class);
    }

    @Test
    void assign_unknownProgram_throwsNotFound() {
        when(trainingProgramRepository.findByIdAndUserIdAndDeletedAtIsNull(PROGRAM_ID, TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.assign(PROGRAM_ID, new ProgramAssignmentRequest(CLIENT_ID, A_MONDAY)))
                .isInstanceOf(ProgramNotFoundException.class);
    }

    @Test
    void assign_emptyProgram_throwsInvalidStructure() {
        program.getWorkouts().clear();

        assertThatThrownBy(() -> service.assign(PROGRAM_ID, new ProgramAssignmentRequest(CLIENT_ID, A_MONDAY)))
                .isInstanceOf(InvalidProgramStructureException.class);
    }

    @Test
    void assign_overlappingActiveAssignment_throwsDuplicate() {
        when(programAssignmentRepository.existsByProgramIdAndClientIdAndCancelledAtIsNullAndEndDateGreaterThanEqual(
                eq(PROGRAM_ID), eq(CLIENT_ID), any())).thenReturn(true);

        assertThatThrownBy(() -> service.assign(PROGRAM_ID, new ProgramAssignmentRequest(CLIENT_ID, A_MONDAY)))
                .isInstanceOf(DuplicateResourceException.class);
    }

    @Test
    void assign_deletedTemplate_throwsInvalidStructure() {
        when(workoutTemplateRepository.findByIdAndUserIdAndDeletedAtIsNull(TEMPLATE_ID, TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.assign(PROGRAM_ID, new ProgramAssignmentRequest(CLIENT_ID, A_MONDAY)))
                .isInstanceOf(InvalidProgramStructureException.class);
    }

    @Test
    void cancel_softDeletesFutureNotStartedOccurrences() {
        ProgramAssignment assignment = new ProgramAssignment();
        assignment.setId(ASSIGNMENT_ID);
        when(programAssignmentRepository.findByIdAndTrainerId(ASSIGNMENT_ID, TRAINER_ID)).thenReturn(Optional.of(assignment));
        WorkoutSession future = new WorkoutSession();
        future.setScheduledFor(LocalDate.now().plusDays(1));
        when(workoutSessionRepository.findByProgramAssignmentIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForGreaterThanEqual(
                eq(ASSIGNMENT_ID), any())).thenReturn(List.of(future));

        service.cancel(ASSIGNMENT_ID);

        assertThat(assignment.getCancelledAt()).isNotNull();
        assertThat(future.getDeletedAt()).isNotNull();
    }

    @Test
    void cancel_notOwnedByTrainer_throwsNotFound() {
        when(programAssignmentRepository.findByIdAndTrainerId(ASSIGNMENT_ID, TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.cancel(ASSIGNMENT_ID)).isInstanceOf(ProgramAssignmentNotFoundException.class);
    }

    @Test
    void cancelActiveAssignmentsForPair_cancelsEveryActiveAssignment() {
        ProgramAssignment a1 = new ProgramAssignment();
        a1.setId(1L);
        ProgramAssignment a2 = new ProgramAssignment();
        a2.setId(2L);
        when(programAssignmentRepository.findByTrainerIdAndClientIdAndCancelledAtIsNull(TRAINER_ID, CLIENT_ID))
                .thenReturn(List.of(a1, a2));

        service.cancelActiveAssignmentsForPair(TRAINER_ID, CLIENT_ID);

        assertThat(a1.getCancelledAt()).isNotNull();
        assertThat(a2.getCancelledAt()).isNotNull();
    }

    private static Long eq(Long value) {
        return org.mockito.ArgumentMatchers.eq(value);
    }
}
