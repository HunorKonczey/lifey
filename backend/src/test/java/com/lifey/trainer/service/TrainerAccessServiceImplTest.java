package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.trainer.TrainerClient;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.dto.MyTrainerResponse;
import com.lifey.trainer.dto.TrainerClientResponse;
import com.lifey.trainer.exception.NotYourClientException;
import com.lifey.user.User;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TrainerAccessServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;

    @Mock
    TrainerClientRepository trainerClientRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    TrainerAccessServiceImpl service;

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

        List<TrainerClientResponse> result = service.findActiveClientsForTrainer();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.clientId()).isEqualTo(CLIENT_ID);
            assertThat(r.clientEmail()).isEqualTo("client@example.com");
        });
    }

    @Test
    void revokeClient_setsRevokedStatus() {
        when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
        TrainerClient relationship = new TrainerClient();
        relationship.setStatus(TrainerClientStatus.ACTIVE);
        when(trainerClientRepository.findByTrainerIdAndClientIdAndStatus(TRAINER_ID, CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(Optional.of(relationship));

        service.revokeClient(CLIENT_ID);

        assertThat(relationship.getStatus()).isEqualTo(TrainerClientStatus.REVOKED);
        assertThat(relationship.getRevokedAt()).isNotNull();
        assertThat(relationship.getRevokedBy()).isEqualTo(TRAINER_ID);
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
        TrainerClient relationship = new TrainerClient();
        relationship.setStatus(TrainerClientStatus.ACTIVE);
        when(trainerClientRepository.findByTrainerIdAndClientIdAndStatus(TRAINER_ID, CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(Optional.of(relationship));

        service.leaveTrainer(TRAINER_ID);

        assertThat(relationship.getStatus()).isEqualTo(TrainerClientStatus.REVOKED);
        assertThat(relationship.getRevokedBy()).isEqualTo(CLIENT_ID);
    }

    @Test
    void leaveTrainer_throwsWhenNoActiveRelationship() {
        when(currentUserProvider.getUserId()).thenReturn(CLIENT_ID);
        when(trainerClientRepository.findByTrainerIdAndClientIdAndStatus(TRAINER_ID, CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.leaveTrainer(TRAINER_ID)).isInstanceOf(ResourceNotFoundException.class);
    }
}
