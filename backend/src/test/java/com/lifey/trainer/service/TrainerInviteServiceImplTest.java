package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.billing.service.SeatLimitService;
import com.lifey.common.domain.BaseEntity;
import com.lifey.mail.service.MailService;
import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.TrainerInviteProperties;
import com.lifey.trainer.dto.PendingInviteResponse;
import com.lifey.trainer.dto.RespondToInviteRequest;
import com.lifey.trainer.dto.TrainerInviteRequest;
import com.lifey.trainer.dto.TrainerInviteResponse;
import com.lifey.trainer.entity.TrainerClient;
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

    /** Unstubbed: void, so every seat check is a no-op — these tests aren't about billing enforcement. */
    @Mock
    SeatLimitService seatLimitService;

    @Mock
    PushService pushService;

    @Mock
    UserSettingsRepository userSettingsRepository;

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
        when(trainerClientRepository.save(any(TrainerClient.class))).thenAnswer(inv -> withId(inv.getArgument(0), 10L));

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
        TrainerInviteRequest request = new TrainerInviteRequest("nobody@example.com");

        assertThatThrownBy(() -> service.invite(request))
                .isInstanceOf(UserNotFoundForInviteException.class);
        verify(trainerClientRepository, never()).save(any());
    }

    @Test
    void invite_throwsWhenInvitingSelf() {
        User self = new User();
        self.setId(TRAINER_ID);
        self.setEmail("me@example.com");
        when(userRepository.findByEmailIgnoreCase("me@example.com")).thenReturn(Optional.of(self));
        TrainerInviteRequest request = new TrainerInviteRequest("me@example.com");

        assertThatThrownBy(() -> service.invite(request))
                .isInstanceOf(SelfInviteException.class);
    }

    @Test
    void invite_throwsWhenAlreadyAnActiveClient() {
        User client = client();
        when(userRepository.findByEmailIgnoreCase("client@example.com")).thenReturn(Optional.of(client));
        when(trainerClientRepository.existsByTrainerIdAndClientIdAndStatus(TRAINER_ID, CLIENT_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(true);
        TrainerInviteRequest request = new TrainerInviteRequest("client@example.com");

        assertThatThrownBy(() -> service.invite(request))
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
        TrainerInviteRequest request = new TrainerInviteRequest("client@example.com");

        assertThatThrownBy(() -> service.invite(request))
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
        TrainerInviteRequest request = new TrainerInviteRequest("client@example.com");

        assertThatThrownBy(() -> service.invite(request))
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
        invite.setTrainer(withId(new User(), TRAINER_ID));
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
        RespondToInviteRequest request = new RespondToInviteRequest(true);

        assertThatThrownBy(() -> service.respond(99L, request))
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
        invite.setTrainer(withId(new User(), TRAINER_ID));
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

    // ---- reminder (LIF-103) ----

    private TrainerClient pendingInvite(Instant createdAt, Instant lastRemindedAt) {
        TrainerClient invite = new TrainerClient();
        invite.setId(10L);
        User trainer = new User();
        trainer.setId(TRAINER_ID);
        trainer.setFirstName("Kata");
        trainer.setLastName("Coach");
        trainer.setEmail("kata@example.com");
        invite.setTrainer(trainer);
        invite.setClient(client());
        invite.setStatus(TrainerClientStatus.PENDING);
        invite.setCreatedAt(createdAt);
        invite.setExpiresAt(createdAt.plusSeconds(24 * 3600));
        invite.setLastRemindedAt(lastRemindedAt);
        when(trainerClientRepository.findByIdAndTrainerIdAndStatus(10L, TRAINER_ID, TrainerClientStatus.PENDING))
                .thenReturn(Optional.of(invite));
        return invite;
    }

    @Test
    void remind_pushesTheClientAndRecordsWhen() {
        TrainerClient invite = pendingInvite(Instant.now().minusSeconds(5 * 3600), null);
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());

        TrainerInviteResponse result = service.remind(10L);

        assertThat(invite.getLastRemindedAt()).isNotNull();
        assertThat(result.lastRemindedAt()).isEqualTo(invite.getLastRemindedAt());
        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(CLIENT_ID), captor.capture());
        assertThat(captor.getValue().title()).isEqualTo("A trainer is waiting for your answer");
        assertThat(captor.getValue().body()).contains("Kata Coach");
        assertThat(captor.getValue().data()).containsEntry("type", "trainer_invite");
        // The email channel is off in these tests: no mail, and the invite's own expiry is untouched.
        verifyNoInteractions(mailService);
        assertThat(invite.getExpiresAt()).isEqualTo(invite.getCreatedAt().plusSeconds(24 * 3600));
    }

    @Test
    void remind_speaksHungarianToAHungarianClient() {
        pendingInvite(Instant.now().minusSeconds(5 * 3600), null);
        UserSettings settings = new UserSettings();
        settings.setLanguage(LanguagePreference.HUNGARIAN);
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.of(settings));

        service.remind(10L);

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(CLIENT_ID), captor.capture());
        assertThat(captor.getValue().title()).isEqualTo("Egy edző válaszodra vár");
    }

    @Test
    void remind_withTheEmailChannelOnSendsTheMailAgainWithFreshLinks() {
        TrainerClient invite = pendingInvite(Instant.now().minusSeconds(5 * 3600), null);
        invite.setEmailTokenHash("old-hash");
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());
        when(trainerInviteProperties.emailEnabled()).thenReturn(true);
        when(trainerInviteProperties.publicBaseUrl()).thenReturn("https://api.lifey.test");

        service.remind(10L);

        assertThat(invite.getEmailTokenHash()).isNotEqualTo("old-hash").hasSize(64);
        ArgumentCaptor<String> accept = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> decline = ArgumentCaptor.forClass(String.class);
        verify(mailService).sendTrainerInviteEmail(eq(invite.getClient()), eq(invite.getTrainer()), accept.capture(), decline.capture());
        assertThat(accept.getValue()).startsWith("https://api.lifey.test/api/v1/trainer-invites/email/respond?token=")
                .endsWith("&accept=true");
        assertThat(decline.getValue()).endsWith("&accept=false");
    }

    @Test
    void remind_isRefusedWithinTheCooldownOfTheInviteItself() {
        TrainerClient invite = pendingInvite(Instant.now().minusSeconds(3600), null);

        assertThatThrownBy(() -> service.remind(10L)).isInstanceOf(InviteRateLimitedException.class);

        assertThat(invite.getLastRemindedAt()).isNull();
        verifyNoInteractions(pushService, mailService);
    }

    @Test
    void remind_isRefusedWithinTheCooldownOfTheLastReminder_andAllowedAfterIt() {
        TrainerClient invite = pendingInvite(Instant.now().minusSeconds(10 * 3600), Instant.now().minusSeconds(3600));

        assertThatThrownBy(() -> service.remind(10L)).isInstanceOf(InviteRateLimitedException.class);

        invite.setLastRemindedAt(Instant.now().minusSeconds(5 * 3600));
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());
        service.remind(10L);
        verify(pushService).sendToUser(eq(CLIENT_ID), any());
    }

    @Test
    void remind_anInviteThatIsNotPendingOrHasRunOutIsNotFound() {
        when(trainerClientRepository.findByIdAndTrainerIdAndStatus(11L, TRAINER_ID, TrainerClientStatus.PENDING))
                .thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.remind(11L)).isInstanceOf(InviteNotFoundException.class);

        TrainerClient lapsed = pendingInvite(Instant.now().minusSeconds(30 * 3600), null);
        assertThatThrownBy(() -> service.remind(10L)).isInstanceOf(InviteNotFoundException.class);
        assertThat(lapsed.getLastRemindedAt()).isNull();
        verifyNoInteractions(pushService, mailService);
    }

    private static User client() {
        User client = new User();
        client.setId(CLIENT_ID);
        client.setEmail("client@example.com");
        return client;
    }

    private static <T extends BaseEntity> T withId(T entity, Long id) {
        entity.setId(id);
        return entity;
    }
}
