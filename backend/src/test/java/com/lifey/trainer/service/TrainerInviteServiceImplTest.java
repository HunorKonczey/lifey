package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.mail.service.MailService;
import com.lifey.trainer.TrainerClient;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.TrainerInviteProperties;
import com.lifey.trainer.dto.PendingInviteResponse;
import com.lifey.trainer.dto.RespondToInviteRequest;
import com.lifey.trainer.dto.TrainerInviteRequest;
import com.lifey.trainer.dto.TrainerInviteResponse;
import com.lifey.trainer.exception.AlreadyClientException;
import com.lifey.trainer.exception.InviteNotFoundException;
import com.lifey.trainer.exception.InviteRateLimitedException;
import com.lifey.trainer.exception.SelfInviteException;
import com.lifey.trainer.exception.UserNotFoundForInviteException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TrainerInviteServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;

    @Mock
    TrainerClientRepository trainerClientRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @Mock
    MailService mailService;

    /** Unstubbed: {@code emailEnabled()} defaults to {@code false}, matching the feature's off-by-default setting. */
    @Mock
    TrainerInviteProperties trainerInviteProperties;

    @InjectMocks
    TrainerInviteServiceImpl service;

    @BeforeEach
    void setUp() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
    }

    @Test
    void invite_createsPendingInviteWithA24HourWindow() {
        User client = client();
        when(userRepository.findByEmailIgnoreCase("client@example.com")).thenReturn(Optional.of(client));
        when(userRepository.getReferenceById(TRAINER_ID)).thenReturn(new User());
        when(trainerClientRepository.findFirstByTrainerIdAndClientIdOrderByCreatedAtDesc(TRAINER_ID, CLIENT_ID))
                .thenReturn(Optional.empty());
        when(trainerClientRepository.save(any(TrainerClient.class))).thenAnswer(inv -> {
            TrainerClient tc = inv.getArgument(0);
            tc.setId(10L);
            return tc;
        });

        TrainerInviteResponse result = service.invite(new TrainerInviteRequest("client@example.com"));

        assertThat(result.id()).isEqualTo(10L);
        assertThat(result.clientEmail()).isEqualTo("client@example.com");

        ArgumentCaptor<TrainerClient> captor = ArgumentCaptor.forClass(TrainerClient.class);
        verify(trainerClientRepository).save(captor.capture());
        TrainerClient saved = captor.getValue();
        assertThat(saved.getStatus()).isEqualTo(TrainerClientStatus.PENDING);
        assertThat(saved.getExpiresAt()).isEqualTo(saved.getCreatedAt().plusSeconds(24 * 3600));
    }

    @Test
    void invite_throwsWhenNoUserWithThatEmail() {
        when(userRepository.findByEmailIgnoreCase("nobody@example.com")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.invite(new TrainerInviteRequest("nobody@example.com")))
                .isInstanceOf(UserNotFoundForInviteException.class);
        verify(trainerClientRepository, never()).save(any());
    }

    @Test
    void invite_throwsWhenInvitingSelf() {
        User self = new User();
        self.setId(TRAINER_ID);
        self.setEmail("me@example.com");
        when(userRepository.findByEmailIgnoreCase("me@example.com")).thenReturn(Optional.of(self));

        assertThatThrownBy(() -> service.invite(new TrainerInviteRequest("me@example.com")))
                .isInstanceOf(SelfInviteException.class);
    }

    @Test
    void invite_throwsWhenAlreadyAnActiveClient() {
        User client = client();
        when(userRepository.findByEmailIgnoreCase("client@example.com")).thenReturn(Optional.of(client));
        when(trainerClientRepository.existsByTrainerIdAndClientIdAndStatus(TRAINER_ID, CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(true);

        assertThatThrownBy(() -> service.invite(new TrainerInviteRequest("client@example.com")))
                .isInstanceOf(AlreadyClientException.class);
        verify(trainerClientRepository, never()).save(any());
    }

    @Test
    void invite_throwsWhenTheSamePairWasInvitedWithinTheLast24Hours() {
        User client = client();
        when(userRepository.findByEmailIgnoreCase("client@example.com")).thenReturn(Optional.of(client));
        TrainerClient recent = new TrainerClient();
        recent.setCreatedAt(Instant.now().minusSeconds(3600));
        when(trainerClientRepository.findFirstByTrainerIdAndClientIdOrderByCreatedAtDesc(TRAINER_ID, CLIENT_ID))
                .thenReturn(Optional.of(recent));

        assertThatThrownBy(() -> service.invite(new TrainerInviteRequest("client@example.com")))
                .isInstanceOf(InviteRateLimitedException.class);
        verify(trainerClientRepository, never()).save(any());
    }

    @Test
    void invite_allowsReinviteAfterThe24HourWindowPasses() {
        User client = client();
        when(userRepository.findByEmailIgnoreCase("client@example.com")).thenReturn(Optional.of(client));
        when(userRepository.getReferenceById(TRAINER_ID)).thenReturn(new User());
        TrainerClient old = new TrainerClient();
        old.setCreatedAt(Instant.now().minusSeconds(25 * 3600));
        when(trainerClientRepository.findFirstByTrainerIdAndClientIdOrderByCreatedAtDesc(TRAINER_ID, CLIENT_ID))
                .thenReturn(Optional.of(old));
        when(trainerClientRepository.save(any(TrainerClient.class))).thenAnswer(inv -> inv.getArgument(0));

        service.invite(new TrainerInviteRequest("client@example.com"));

        verify(trainerClientRepository).save(any());
    }

    @Test
    void invite_throwsWhenDailyCapReached() {
        User client = client();
        when(userRepository.findByEmailIgnoreCase("client@example.com")).thenReturn(Optional.of(client));
        when(trainerClientRepository.findFirstByTrainerIdAndClientIdOrderByCreatedAtDesc(TRAINER_ID, CLIENT_ID))
                .thenReturn(Optional.empty());
        when(trainerClientRepository.countByTrainerIdAndCreatedAtAfter(eq(TRAINER_ID), any())).thenReturn(20L);

        assertThatThrownBy(() -> service.invite(new TrainerInviteRequest("client@example.com")))
                .isInstanceOf(InviteRateLimitedException.class);
        verify(trainerClientRepository, never()).save(any());
    }

    @Test
    void findPendingForTrainer_mapsToInviteResponses() {
        TrainerClient tc = new TrainerClient();
        tc.setId(5L);
        tc.setClient(client());
        tc.setCreatedAt(Instant.parse("2026-06-01T00:00:00Z"));
        tc.setExpiresAt(Instant.parse("2026-06-02T00:00:00Z"));
        when(trainerClientRepository.findByTrainerIdAndStatusAndExpiresAtAfterOrderByCreatedAtDesc(
                eq(TRAINER_ID), eq(TrainerClientStatus.PENDING), any())).thenReturn(List.of(tc));

        List<TrainerInviteResponse> result = service.findPendingForTrainer();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(5L);
            assertThat(r.clientEmail()).isEqualTo("client@example.com");
        });
    }

    @Test
    void cancel_revokesAPendingInvite() {
        TrainerClient invite = new TrainerClient();
        invite.setStatus(TrainerClientStatus.PENDING);
        invite.setExpiresAt(Instant.now().plusSeconds(3600));
        when(trainerClientRepository.findByIdAndTrainerIdAndStatus(7L, TRAINER_ID, TrainerClientStatus.PENDING))
                .thenReturn(Optional.of(invite));

        service.cancel(7L);

        assertThat(invite.getStatus()).isEqualTo(TrainerClientStatus.REVOKED);
        assertThat(invite.getRevokedAt()).isNotNull();
        assertThat(invite.getRevokedBy()).isEqualTo(TRAINER_ID);
    }

    @Test
    void cancel_throwsWhenInviteDoesNotExist() {
        when(trainerClientRepository.findByIdAndTrainerIdAndStatus(99L, TRAINER_ID, TrainerClientStatus.PENDING))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.cancel(99L)).isInstanceOf(InviteNotFoundException.class);
    }

    @Test
    void cancel_throwsWhenInviteAlreadyExpired() {
        TrainerClient expired = new TrainerClient();
        expired.setExpiresAt(Instant.now().minusSeconds(1));
        when(trainerClientRepository.findByIdAndTrainerIdAndStatus(7L, TRAINER_ID, TrainerClientStatus.PENDING))
                .thenReturn(Optional.of(expired));

        assertThatThrownBy(() -> service.cancel(7L)).isInstanceOf(InviteNotFoundException.class);
    }

    @Test
    void findPendingForClient_mapsToPendingInviteResponses() {
        when(currentUserProvider.getUserId()).thenReturn(CLIENT_ID);
        TrainerClient tc = new TrainerClient();
        tc.setId(3L);
        User trainer = new User();
        trainer.setId(TRAINER_ID);
        trainer.setEmail("trainer@example.com");
        tc.setTrainer(trainer);
        tc.setCreatedAt(Instant.parse("2026-06-01T00:00:00Z"));
        tc.setExpiresAt(Instant.parse("2026-06-02T00:00:00Z"));
        when(trainerClientRepository.findByClientIdAndStatusAndExpiresAtAfterOrderByCreatedAtDesc(
                eq(CLIENT_ID), eq(TrainerClientStatus.PENDING), any())).thenReturn(List.of(tc));

        List<PendingInviteResponse> result = service.findPendingForClient();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(3L);
            assertThat(r.trainerEmail()).isEqualTo("trainer@example.com");
        });
    }

    @Test
    void respond_acceptSetsActive() {
        when(currentUserProvider.getUserId()).thenReturn(CLIENT_ID);
        TrainerClient invite = new TrainerClient();
        invite.setStatus(TrainerClientStatus.PENDING);
        invite.setExpiresAt(Instant.now().plusSeconds(3600));
        when(trainerClientRepository.findByIdAndClientIdAndStatus(4L, CLIENT_ID, TrainerClientStatus.PENDING))
                .thenReturn(Optional.of(invite));

        service.respond(4L, new RespondToInviteRequest(true));

        assertThat(invite.getStatus()).isEqualTo(TrainerClientStatus.ACTIVE);
        assertThat(invite.getRespondedAt()).isNotNull();
    }

    @Test
    void respond_declineSetsDeclined() {
        when(currentUserProvider.getUserId()).thenReturn(CLIENT_ID);
        TrainerClient invite = new TrainerClient();
        invite.setStatus(TrainerClientStatus.PENDING);
        invite.setExpiresAt(Instant.now().plusSeconds(3600));
        when(trainerClientRepository.findByIdAndClientIdAndStatus(4L, CLIENT_ID, TrainerClientStatus.PENDING))
                .thenReturn(Optional.of(invite));

        service.respond(4L, new RespondToInviteRequest(false));

        assertThat(invite.getStatus()).isEqualTo(TrainerClientStatus.DECLINED);
    }

    @Test
    void respond_throwsWhenInviteMissingOrNotOwnedByThisClient() {
        when(currentUserProvider.getUserId()).thenReturn(CLIENT_ID);
        when(trainerClientRepository.findByIdAndClientIdAndStatus(99L, CLIENT_ID, TrainerClientStatus.PENDING))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.respond(99L, new RespondToInviteRequest(true)))
                .isInstanceOf(InviteNotFoundException.class);
    }

    @Test
    void invite_sendsInviteEmailWhenEmailChannelEnabled() {
        when(trainerInviteProperties.emailEnabled()).thenReturn(true);
        when(trainerInviteProperties.publicBaseUrl()).thenReturn("http://localhost:8080");
        User client = client();
        User trainer = new User();
        trainer.setId(TRAINER_ID);
        when(userRepository.findByEmailIgnoreCase("client@example.com")).thenReturn(Optional.of(client));
        when(userRepository.getReferenceById(TRAINER_ID)).thenReturn(trainer);
        when(trainerClientRepository.findFirstByTrainerIdAndClientIdOrderByCreatedAtDesc(TRAINER_ID, CLIENT_ID))
                .thenReturn(Optional.empty());
        when(trainerClientRepository.save(any(TrainerClient.class))).thenAnswer(inv -> inv.getArgument(0));

        service.invite(new TrainerInviteRequest("client@example.com"));

        ArgumentCaptor<TrainerClient> captor = ArgumentCaptor.forClass(TrainerClient.class);
        verify(trainerClientRepository).save(captor.capture());
        assertThat(captor.getValue().getEmailTokenHash()).isNotBlank();

        ArgumentCaptor<String> acceptUrl = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> declineUrl = ArgumentCaptor.forClass(String.class);
        verify(mailService).sendTrainerInviteEmail(eq(client), eq(trainer), acceptUrl.capture(), declineUrl.capture());
        assertThat(acceptUrl.getValue()).startsWith("http://localhost:8080/api/v1/trainer-invites/email/respond?token=")
                .endsWith("&accept=true");
        assertThat(declineUrl.getValue()).endsWith("&accept=false");
    }

    @Test
    void invite_doesNotSendEmailWhenChannelDisabled() {
        User client = client();
        when(userRepository.findByEmailIgnoreCase("client@example.com")).thenReturn(Optional.of(client));
        when(userRepository.getReferenceById(TRAINER_ID)).thenReturn(new User());
        when(trainerClientRepository.findFirstByTrainerIdAndClientIdOrderByCreatedAtDesc(TRAINER_ID, CLIENT_ID))
                .thenReturn(Optional.empty());
        when(trainerClientRepository.save(any(TrainerClient.class))).thenAnswer(inv -> inv.getArgument(0));

        service.invite(new TrainerInviteRequest("client@example.com"));

        verify(mailService, never()).sendTrainerInviteEmail(any(), any(), any(), any());
    }

    @Test
    void respondViaEmailToken_acceptSetsActive() {
        TrainerClient invite = new TrainerClient();
        invite.setStatus(TrainerClientStatus.PENDING);
        invite.setExpiresAt(Instant.now().plusSeconds(3600));
        when(trainerClientRepository.findByEmailTokenHashAndStatus(any(), eq(TrainerClientStatus.PENDING)))
                .thenReturn(Optional.of(invite));

        service.respondViaEmailToken("raw-token", true);

        assertThat(invite.getStatus()).isEqualTo(TrainerClientStatus.ACTIVE);
        assertThat(invite.getRespondedAt()).isNotNull();
    }

    @Test
    void respondViaEmailToken_throwsWhenTokenUnknownOrAlreadyUsed() {
        when(trainerClientRepository.findByEmailTokenHashAndStatus(any(), eq(TrainerClientStatus.PENDING)))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.respondViaEmailToken("raw-token", true))
                .isInstanceOf(InviteNotFoundException.class);
    }

    private static User client() {
        User client = new User();
        client.setId(CLIENT_ID);
        client.setEmail("client@example.com");
        return client;
    }
}
