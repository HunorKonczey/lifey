package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.trainer.ContentAssignmentRepository;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientRevokedEvent;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.dto.MyTrainerResponse;
import com.lifey.trainer.dto.TrainerClientResponse;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.trainer.exception.NotYourClientException;
import com.lifey.nutrition.meal.MealRepository;
import com.lifey.user.User;
import com.lifey.water.WaterEntryRepository;
import com.lifey.weight.WeightEntry;
import com.lifey.weight.WeightEntryRepository;
import com.lifey.workout.session.WorkoutSessionRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TrainerAccessServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;

    @Mock
    TrainerClientRepository trainerClientRepository;

    @Mock
    ContentAssignmentRepository contentAssignmentRepository;

    @Mock
    WeightEntryRepository weightEntryRepository;

    @Mock
    WorkoutSessionRepository workoutSessionRepository;

    @Mock
    MealRepository mealRepository;

    @Mock
    WaterEntryRepository waterEntryRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @Mock
    ApplicationEventPublisher eventPublisher;

    @InjectMocks
    TrainerAccessServiceImpl service;

    private static TrainerClient activeRelationship() {
        TrainerClient relationship = new TrainerClient();
        relationship.setStatus(TrainerClientStatus.ACTIVE);
        User trainer = new User();
        trainer.setId(TRAINER_ID);
        relationship.setTrainer(trainer);
        User client = new User();
        client.setId(CLIENT_ID);
        relationship.setClient(client);
        return relationship;
    }

    @Test
    void requireActiveClient_returnsRelationshipWhenActive() {
        TrainerClient relationship = new TrainerClient();
        when(trainerClientRepository.findByTrainerIdAndClientIdAndStatus(TRAINER_ID, CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(Optional.of(relationship));

        assertThat(service.requireActiveClient(TRAINER_ID, CLIENT_ID)).isSameAs(relationship);
    }

    @Test
    void requireActiveClient_throwsWhenNoActiveRelationship() {
        when(trainerClientRepository.findByTrainerIdAndClientIdAndStatus(TRAINER_ID, CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.requireActiveClient(TRAINER_ID, CLIENT_ID))
                .isInstanceOf(NotYourClientException.class);
    }

    @Test
    void findActiveClientsForTrainer_mapsToClientResponses() {
        when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
        TrainerClient tc = new TrainerClient();
        User client = new User();
        client.setId(CLIENT_ID);
        client.setEmail("client@example.com");
        tc.setClient(client);
        tc.setRespondedAt(Instant.parse("2026-06-01T00:00:00Z"));
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(tc));
        when(weightEntryRepository.findAllByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(eq(CLIENT_ID), any()))
                .thenReturn(List.of());
        when(contentAssignmentRepository.countByTrainerIdAndClientId(TRAINER_ID, CLIENT_ID)).thenReturn(2L);
        when(workoutSessionRepository.countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual(eq(CLIENT_ID), any()))
                .thenReturn(8L);
        when(mealRepository.findMaxDateTimeByUserId(CLIENT_ID)).thenReturn(Optional.empty());
        when(waterEntryRepository.findMaxConsumedAtByUserId(CLIENT_ID)).thenReturn(Optional.empty());
        when(workoutSessionRepository.findMaxStartedAtByUserId(CLIENT_ID)).thenReturn(Optional.empty());
        when(workoutSessionRepository.countMissedOccurrences(eq(TRAINER_ID), eq(CLIENT_ID), any(), any()))
                .thenReturn(0L);

        List<TrainerClientResponse> result = service.findActiveClientsForTrainer();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.clientId()).isEqualTo(CLIENT_ID);
            assertThat(r.clientEmail()).isEqualTo("client@example.com");
            assertThat(r.weightTrend()).isEmpty();
            assertThat(r.assignedPlanCount()).isEqualTo(2);
            assertThat(r.workoutsPerWeek()).isEqualTo(2);
            assertThat(r.lastActivityAt()).isNull();
            assertThat(r.lastWeightAt()).isNull();
            assertThat(r.missedWorkoutCount()).isZero();
        });
    }

    @Test
    void findActiveClientsForTrainer_computesLastActivityAsMaxAcrossSources() {
        when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
        TrainerClient tc = new TrainerClient();
        User client = new User();
        client.setId(CLIENT_ID);
        client.setEmail("client@example.com");
        tc.setClient(client);
        tc.setRespondedAt(Instant.parse("2026-06-01T00:00:00Z"));
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(tc));

        Instant mealTime = Instant.parse("2026-07-01T10:00:00Z");
        Instant waterTime = Instant.parse("2026-07-05T10:00:00Z"); // the latest of the four
        Instant workoutTime = Instant.parse("2026-07-03T10:00:00Z");
        Instant weightRecordedAt = Instant.parse("2026-07-02T10:00:00Z");
        LocalDate weightDate = LocalDate.parse("2026-07-02");

        WeightEntry newestWeight = new WeightEntry();
        newestWeight.setDate(weightDate);
        newestWeight.setRecordedAt(weightRecordedAt);
        newestWeight.setWeight(80.0);
        when(weightEntryRepository.findAllByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(eq(CLIENT_ID), any()))
                .thenReturn(List.of(newestWeight));
        when(contentAssignmentRepository.countByTrainerIdAndClientId(TRAINER_ID, CLIENT_ID)).thenReturn(0L);
        when(workoutSessionRepository.countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual(eq(CLIENT_ID), any()))
                .thenReturn(0L);
        when(mealRepository.findMaxDateTimeByUserId(CLIENT_ID)).thenReturn(Optional.of(mealTime));
        when(waterEntryRepository.findMaxConsumedAtByUserId(CLIENT_ID)).thenReturn(Optional.of(waterTime));
        when(workoutSessionRepository.findMaxStartedAtByUserId(CLIENT_ID)).thenReturn(Optional.of(workoutTime));
        when(workoutSessionRepository.countMissedOccurrences(eq(TRAINER_ID), eq(CLIENT_ID), any(), any()))
                .thenReturn(3L);

        List<TrainerClientResponse> result = service.findActiveClientsForTrainer();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.lastActivityAt()).isEqualTo(waterTime);
            assertThat(r.lastWeightAt()).isEqualTo(weightDate);
            assertThat(r.missedWorkoutCount()).isEqualTo(3);
        });
    }

    @Test
    void revokeClient_setsRevokedStatus() {
        when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
        TrainerClient relationship = activeRelationship();
        when(trainerClientRepository.findByTrainerIdAndClientIdAndStatus(TRAINER_ID, CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(Optional.of(relationship));

        service.revokeClient(CLIENT_ID);

        assertThat(relationship.getStatus()).isEqualTo(TrainerClientStatus.REVOKED);
        assertThat(relationship.getRevokedAt()).isNotNull();
        assertThat(relationship.getRevokedBy()).isEqualTo(TRAINER_ID);
        verify(eventPublisher).publishEvent(new TrainerClientRevokedEvent(TRAINER_ID, CLIENT_ID));
    }

    @Test
    void revokeClient_throwsWhenNotAnActiveClient() {
        when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
        when(trainerClientRepository.findByTrainerIdAndClientIdAndStatus(TRAINER_ID, CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.revokeClient(CLIENT_ID)).isInstanceOf(NotYourClientException.class);
    }

    @Test
    void findActiveTrainersForClient_mapsToMyTrainerResponses() {
        when(currentUserProvider.getUserId()).thenReturn(CLIENT_ID);
        TrainerClient tc = new TrainerClient();
        User trainer = new User();
        trainer.setId(TRAINER_ID);
        trainer.setEmail("trainer@example.com");
        tc.setTrainer(trainer);
        tc.setRespondedAt(Instant.parse("2026-06-01T00:00:00Z"));
        when(trainerClientRepository.findByClientIdAndStatusOrderByRespondedAtDesc(CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(tc));

        List<MyTrainerResponse> result = service.findActiveTrainersForClient();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.trainerId()).isEqualTo(TRAINER_ID);
            assertThat(r.trainerEmail()).isEqualTo("trainer@example.com");
        });
    }

    @Test
    void leaveTrainer_setsRevokedStatus() {
        when(currentUserProvider.getUserId()).thenReturn(CLIENT_ID);
        TrainerClient relationship = activeRelationship();
        when(trainerClientRepository.findByTrainerIdAndClientIdAndStatus(TRAINER_ID, CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(Optional.of(relationship));

        service.leaveTrainer(TRAINER_ID);

        assertThat(relationship.getStatus()).isEqualTo(TrainerClientStatus.REVOKED);
        assertThat(relationship.getRevokedBy()).isEqualTo(CLIENT_ID);
        verify(eventPublisher).publishEvent(new TrainerClientRevokedEvent(TRAINER_ID, CLIENT_ID));
    }

    @Test
    void leaveTrainer_throwsWhenNoActiveRelationship() {
        when(currentUserProvider.getUserId()).thenReturn(CLIENT_ID);
        when(trainerClientRepository.findByTrainerIdAndClientIdAndStatus(TRAINER_ID, CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.leaveTrainer(TRAINER_ID)).isInstanceOf(ResourceNotFoundException.class);
    }
}
