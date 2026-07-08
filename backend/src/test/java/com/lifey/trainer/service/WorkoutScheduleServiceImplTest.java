package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.trainer.ContentType;
import com.lifey.trainer.Recurrence;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.WorkoutScheduleRepository;
import com.lifey.trainer.dto.AssignmentRequest;
import com.lifey.trainer.dto.AssignmentResponse;
import com.lifey.trainer.dto.OccurrenceStatus;
import com.lifey.trainer.dto.ScheduleRequest;
import com.lifey.trainer.dto.ScheduleResponse;
import com.lifey.trainer.dto.TrainerCalendarSessionResponse;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.trainer.entity.WorkoutSchedule;
import com.lifey.trainer.exception.CalendarRangeExceededException;
import com.lifey.trainer.exception.EmptyRecurrenceException;
import com.lifey.trainer.exception.OccurrenceNotCancellableException;
import com.lifey.trainer.exception.ScheduleHorizonExceededException;
import com.lifey.trainer.exception.ScheduleInPastException;
import com.lifey.trainer.exception.ScheduleNotFoundException;
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

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class WorkoutScheduleServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;
    private static final Long TEMPLATE_ID = 7L;
    private static final Long SCHEDULE_ID = 9L;

    @Mock
    WorkoutScheduleRepository workoutScheduleRepository;

    @Mock
    WorkoutSessionRepository workoutSessionRepository;

    @Mock
    WorkoutTemplateRepository workoutTemplateRepository;

    @Mock
    ContentAssignmentService contentAssignmentService;

    @Mock
    TrainerAccessService trainerAccessService;

    @Mock
    TrainerClientRepository trainerClientRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    WorkoutScheduleServiceImpl service;

    WorkoutTemplate sourceTemplate;

    @BeforeEach
    void stubCommon() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);

        sourceTemplate = new WorkoutTemplate();
        sourceTemplate.setId(TEMPLATE_ID);
        sourceTemplate.setName("Push day");
        lenient().when(workoutTemplateRepository.findByIdAndUserId(TEMPLATE_ID, TRAINER_ID))
                .thenReturn(Optional.of(sourceTemplate));

        User trainer = new User();
        trainer.setId(TRAINER_ID);
        User client = new User();
        client.setId(CLIENT_ID);
        lenient().when(userRepository.getReferenceById(TRAINER_ID)).thenReturn(trainer);
        lenient().when(userRepository.getReferenceById(CLIENT_ID)).thenReturn(client);

        lenient().when(workoutScheduleRepository.save(any(WorkoutSchedule.class))).thenAnswer(invocation -> {
            WorkoutSchedule schedule = invocation.getArgument(0);
            schedule.setId(SCHEDULE_ID);
            return schedule;
        });
    }

    private ScheduleRequest onceRequest(LocalDate date) {
        return new ScheduleRequest(CLIENT_ID, TEMPLATE_ID, Recurrence.ONCE, List.of(), LocalTime.of(18, 0), date, date);
    }

    @Test
    void create_reusesLiveClientCopy_whenOneExists() {
        WorkoutTemplate clientCopy = new WorkoutTemplate();
        clientCopy.setId(55L);
        clientCopy.setName("Push day");
        when(workoutTemplateRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(
                CLIENT_ID, TRAINER_ID, TEMPLATE_ID)).thenReturn(Optional.of(clientCopy));

        ScheduleResponse response = service.create(onceRequest(LocalDate.now().plusDays(1)));

        verify(contentAssignmentService, never()).assign(any());
        verify(workoutSessionRepository, times(1)).save(any(WorkoutSession.class));
        assertThat(response.occurrencesCreated()).isEqualTo(1);
        assertThat(response.templateName()).isEqualTo("Push day");
    }

    @Test
    void create_assignsFreshCopy_whenNoLiveCopyExists() {
        when(workoutTemplateRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(
                CLIENT_ID, TRAINER_ID, TEMPLATE_ID)).thenReturn(Optional.empty());
        when(contentAssignmentService.assign(new AssignmentRequest(CLIENT_ID, ContentType.TEMPLATE, TEMPLATE_ID)))
                .thenReturn(new AssignmentResponse(1L, ContentType.TEMPLATE, TEMPLATE_ID, 55L, Instant.now(), false));
        WorkoutTemplate clientCopy = new WorkoutTemplate();
        clientCopy.setId(55L);
        clientCopy.setName("Push day");
        when(workoutTemplateRepository.getReferenceById(55L)).thenReturn(clientCopy);

        service.create(onceRequest(LocalDate.now().plusDays(1)));

        verify(contentAssignmentService).assign(new AssignmentRequest(CLIENT_ID, ContentType.TEMPLATE, TEMPLATE_ID));
    }

    @Test
    void create_materializesOneSessionPerOccurrence() {
        when(workoutTemplateRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(
                CLIENT_ID, TRAINER_ID, TEMPLATE_ID)).thenReturn(Optional.of(sourceTemplate));

        LocalDate start = LocalDate.now().plusDays(1);
        ScheduleRequest request = new ScheduleRequest(
                CLIENT_ID, TEMPLATE_ID, Recurrence.DAILY, List.of(), null, start, start.plusDays(3));

        ScheduleResponse response = service.create(request);

        ArgumentCaptor<WorkoutSession> captor = ArgumentCaptor.forClass(WorkoutSession.class);
        verify(workoutSessionRepository, times(4)).save(captor.capture());
        assertThat(response.occurrencesCreated()).isEqualTo(4);
        assertThat(captor.getAllValues()).allSatisfy(session -> {
            assertThat(session.getScheduleId()).isEqualTo(SCHEDULE_ID);
            assertThat(session.getStartedAt()).isNull();
            assertThat(session.getTemplateName()).isEqualTo("Push day");
        });
    }

    @Test
    void create_pastStartDate_throws() {
        assertThatThrownBy(() -> service.create(onceRequest(LocalDate.now().minusDays(1))))
                .isInstanceOf(ScheduleInPastException.class);
    }

    @Test
    void create_weeklyWithNoDays_throwsEmptyRecurrence() {
        LocalDate start = LocalDate.now().plusDays(1);
        ScheduleRequest request = new ScheduleRequest(
                CLIENT_ID, TEMPLATE_ID, Recurrence.WEEKLY, List.of(), null, start, start.plusWeeks(1));

        assertThatThrownBy(() -> service.create(request)).isInstanceOf(EmptyRecurrenceException.class);
    }

    @Test
    void create_beyondThreeMonthHorizon_throws() {
        LocalDate start = LocalDate.now().plusDays(1);
        ScheduleRequest request = new ScheduleRequest(
                CLIENT_ID, TEMPLATE_ID, Recurrence.DAILY, List.of(), null, start, start.plusMonths(3).plusDays(1));

        assertThatThrownBy(() -> service.create(request)).isInstanceOf(ScheduleHorizonExceededException.class);
    }

    @Test
    void create_foreignTemplate_throwsNotFound() {
        when(workoutTemplateRepository.findByIdAndUserId(TEMPLATE_ID, TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.create(onceRequest(LocalDate.now().plusDays(1))))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void cancelSchedule_softDeletesOnlyFutureNotStartedOccurrences() {
        WorkoutSchedule schedule = new WorkoutSchedule();
        schedule.setId(SCHEDULE_ID);
        when(workoutScheduleRepository.findByIdAndTrainerId(SCHEDULE_ID, TRAINER_ID)).thenReturn(Optional.of(schedule));
        WorkoutSession future = new WorkoutSession();
        future.setScheduledFor(LocalDate.now().plusDays(1));
        when(workoutSessionRepository.findByScheduleIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForGreaterThanEqual(
                eq(SCHEDULE_ID), any())).thenReturn(List.of(future));

        service.cancelSchedule(SCHEDULE_ID);

        assertThat(schedule.getCancelledAt()).isNotNull();
        assertThat(future.getDeletedAt()).isNotNull();
    }

    @Test
    void cancelSchedule_notOwnedByTrainer_throwsNotFound() {
        when(workoutScheduleRepository.findByIdAndTrainerId(SCHEDULE_ID, TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.cancelSchedule(SCHEDULE_ID)).isInstanceOf(ScheduleNotFoundException.class);
    }

    @Test
    void cancelOccurrence_futureNotStarted_softDeletes() {
        WorkoutSession occurrence = new WorkoutSession();
        occurrence.setId(20L);
        occurrence.setScheduleId(SCHEDULE_ID);
        occurrence.setScheduledFor(LocalDate.now().plusDays(1));
        when(workoutSessionRepository.findById(20L)).thenReturn(Optional.of(occurrence));
        when(workoutScheduleRepository.findByIdAndTrainerId(SCHEDULE_ID, TRAINER_ID))
                .thenReturn(Optional.of(new WorkoutSchedule()));

        service.cancelOccurrence(20L);

        assertThat(occurrence.getDeletedAt()).isNotNull();
    }

    @Test
    void cancelOccurrence_alreadyStarted_throwsConflict() {
        WorkoutSession occurrence = new WorkoutSession();
        occurrence.setId(20L);
        occurrence.setScheduleId(SCHEDULE_ID);
        occurrence.setScheduledFor(LocalDate.now().plusDays(1));
        occurrence.setStartedAt(Instant.now());
        when(workoutSessionRepository.findById(20L)).thenReturn(Optional.of(occurrence));
        when(workoutScheduleRepository.findByIdAndTrainerId(SCHEDULE_ID, TRAINER_ID))
                .thenReturn(Optional.of(new WorkoutSchedule()));

        assertThatThrownBy(() -> service.cancelOccurrence(20L)).isInstanceOf(OccurrenceNotCancellableException.class);
    }

    @Test
    void cancelOccurrence_pastDate_throwsConflict() {
        WorkoutSession occurrence = new WorkoutSession();
        occurrence.setId(20L);
        occurrence.setScheduleId(SCHEDULE_ID);
        occurrence.setScheduledFor(LocalDate.now().minusDays(1));
        when(workoutSessionRepository.findById(20L)).thenReturn(Optional.of(occurrence));
        when(workoutScheduleRepository.findByIdAndTrainerId(SCHEDULE_ID, TRAINER_ID))
                .thenReturn(Optional.of(new WorkoutSchedule()));

        assertThatThrownBy(() -> service.cancelOccurrence(20L)).isInstanceOf(OccurrenceNotCancellableException.class);
    }

    @Test
    void cancelOccurrence_belongsToAnotherTrainer_throwsNotFound() {
        WorkoutSession occurrence = new WorkoutSession();
        occurrence.setId(20L);
        occurrence.setScheduleId(SCHEDULE_ID);
        when(workoutSessionRepository.findById(20L)).thenReturn(Optional.of(occurrence));
        when(workoutScheduleRepository.findByIdAndTrainerId(SCHEDULE_ID, TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.cancelOccurrence(20L)).isInstanceOf(ScheduleNotFoundException.class);
    }

    @Test
    void cancelOccurrence_notScheduled_throwsNotFound() {
        WorkoutSession occurrence = new WorkoutSession();
        occurrence.setId(20L);
        when(workoutSessionRepository.findById(20L)).thenReturn(Optional.of(occurrence));

        assertThatThrownBy(() -> service.cancelOccurrence(20L)).isInstanceOf(ScheduleNotFoundException.class);
    }

    @Test
    void findScheduledSessionsForTrainer_aggregatesAcrossActiveClients() {
        User anna = new User();
        anna.setId(CLIENT_ID);
        anna.setEmail("anna@example.com");
        TrainerClient trainerClient = new TrainerClient();
        trainerClient.setClient(anna);
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(trainerClient));

        WorkoutSession occurrence = new WorkoutSession();
        occurrence.setId(30L);
        occurrence.setUser(anna);
        occurrence.setScheduledFor(LocalDate.of(2026, 7, 9));
        occurrence.setTemplateName("Push day");
        occurrence.setScheduleId(SCHEDULE_ID);
        when(workoutSessionRepository
                .findByUserIdInAndScheduledForIsNotNullAndScheduledForBetweenOrderByScheduledForAscScheduledTimeAsc(
                        List.of(CLIENT_ID), LocalDate.of(2026, 7, 6), LocalDate.of(2026, 7, 13)))
                .thenReturn(List.of(occurrence));

        List<TrainerCalendarSessionResponse> result = service.findScheduledSessionsForTrainer(
                LocalDate.of(2026, 7, 6), LocalDate.of(2026, 7, 13));

        assertThat(result).hasSize(1);
        assertThat(result.getFirst().clientId()).isEqualTo(CLIENT_ID);
        assertThat(result.getFirst().clientEmail()).isEqualTo("anna@example.com");
        assertThat(result.getFirst().status()).isEqualTo(OccurrenceStatus.UPCOMING);
    }

    @Test
    void findScheduledSessionsForTrainer_noActiveClients_returnsEmpty() {
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of());

        List<TrainerCalendarSessionResponse> result = service.findScheduledSessionsForTrainer(
                LocalDate.of(2026, 7, 6), LocalDate.of(2026, 7, 13));

        assertThat(result).isEmpty();
        verify(workoutSessionRepository, never())
                .findByUserIdInAndScheduledForIsNotNullAndScheduledForBetweenOrderByScheduledForAscScheduledTimeAsc(
                        any(), any(), any());
    }

    @Test
    void findScheduledSessionsForTrainer_rangeBeyond62Days_throws() {
        LocalDate from = LocalDate.of(2026, 7, 6);

        assertThatThrownBy(() -> service.findScheduledSessionsForTrainer(from, from.plusDays(63)))
                .isInstanceOf(CalendarRangeExceededException.class);
    }

    @Test
    void findScheduledSessionsForTrainer_toBeforeFrom_throws() {
        LocalDate from = LocalDate.of(2026, 7, 6);

        assertThatThrownBy(() -> service.findScheduledSessionsForTrainer(from, from.minusDays(1)))
                .isInstanceOf(CalendarRangeExceededException.class);
    }

    @Test
    void cancelActiveSchedulesForPair_cancelsEveryActiveSchedule() {
        WorkoutSchedule schedule1 = new WorkoutSchedule();
        schedule1.setId(SCHEDULE_ID);
        WorkoutSchedule schedule2 = new WorkoutSchedule();
        schedule2.setId(SCHEDULE_ID + 1);
        when(workoutScheduleRepository.findByTrainerIdAndClientIdAndCancelledAtIsNull(TRAINER_ID, CLIENT_ID))
                .thenReturn(List.of(schedule1, schedule2));

        service.cancelActiveSchedulesForPair(TRAINER_ID, CLIENT_ID);

        assertThat(schedule1.getCancelledAt()).isNotNull();
        assertThat(schedule2.getCancelledAt()).isNotNull();
    }
}
