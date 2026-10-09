package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.auth.TokenHasher;
import com.lifey.billing.exception.SeatLimitExceededException;
import com.lifey.billing.service.SeatLimitService;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.TrainerInviteLinkRepository;
import com.lifey.trainer.dto.CreatedTrainerInviteLinkResponse;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.trainer.entity.TrainerInviteLink;
import com.lifey.trainer.exception.AlreadyClientException;
import com.lifey.trainer.exception.InviteNotFoundException;
import com.lifey.trainer.exception.InviteRateLimitedException;
import com.lifey.trainer.exception.SelfInviteException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TrainerInviteLinkServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long USER_ID = 2L;

    @Mock
    TrainerInviteLinkRepository linkRepository;

    @Mock
    TrainerClientRepository trainerClientRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @Mock
    SeatLimitService seatLimitService;

    @InjectMocks
    TrainerInviteLinkServiceImpl service;

    private User trainer;

    @BeforeEach
    void setUp() {
        trainer = new User();
        trainer.setId(TRAINER_ID);
        trainer.setFirstName("Kata");
        trainer.setLastName("Coach");
        trainer.setEmail("kata@example.com");
        lenient().when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
        lenient().when(userRepository.getReferenceById(TRAINER_ID)).thenReturn(trainer);
        lenient().when(linkRepository.save(any(TrainerInviteLink.class))).thenAnswer(inv -> {
            TrainerInviteLink l = inv.getArgument(0);
            if (l.getId() == null) l.setId(77L);
            return l;
        });
    }

    private TrainerInviteLink aLink(String token) {
        TrainerInviteLink link = new TrainerInviteLink();
        link.setId(5L);
        link.setTrainer(trainer);
        link.setTokenHash(TokenHasher.hash(token));
        link.setCreatedAt(Instant.now().minusSeconds(60));
        link.setExpiresAt(Instant.now().plus(Duration.ofDays(3)));
        return link;
    }

    /** A live link, found by its token. */
    private TrainerInviteLink liveLink(String token) {
        TrainerInviteLink link = aLink(token);
        when(linkRepository.findByTokenHash(TokenHasher.hash(token))).thenReturn(Optional.of(link));
        return link;
    }

    // ---- create / list / revoke ----

    @Test
    void create_returnsTheTokenOnceAndStoresOnlyItsHash() {
        CreatedTrainerInviteLinkResponse result = service.create();

        ArgumentCaptor<TrainerInviteLink> captor = ArgumentCaptor.forClass(TrainerInviteLink.class);
        verify(linkRepository).save(captor.capture());
        TrainerInviteLink saved = captor.getValue();
        assertThat(result.token()).isNotBlank();
        assertThat(saved.getTokenHash()).isEqualTo(TokenHasher.hash(result.token())).isNotEqualTo(result.token());
        assertThat(saved.getExpiresAt()).isEqualTo(saved.getCreatedAt().plus(TrainerInviteLinkServiceImpl.LINK_VALIDITY));
        assertThat(result.id()).isEqualTo(77L);
        verify(seatLimitService).assertCanSendInvite(TRAINER_ID);
    }

    @Test
    void create_twoLinksNeverShareAToken() {
        assertThat(service.create().token()).isNotEqualTo(service.create().token());
    }

    @Test
    void create_isRefusedAtTheCapOfLiveLinks() {
        when(linkRepository.countByTrainerIdAndRedeemedAtIsNullAndRevokedAtIsNullAndExpiresAtAfter(anyLong(), any()))
                .thenReturn((long) TrainerInviteLinkServiceImpl.MAX_ACTIVE_LINKS);

        assertThatThrownBy(() -> service.create()).isInstanceOf(InviteRateLimitedException.class);

        verify(linkRepository, never()).save(any());
    }

    @Test
    void create_aTrainerAtTheSeatLimitCannotMakeOne() {
        doThrow(new SeatLimitExceededException("full")).when(seatLimitService).assertCanSendInvite(TRAINER_ID);

        assertThatThrownBy(() -> service.create()).isInstanceOf(SeatLimitExceededException.class);

        verify(linkRepository, never()).save(any());
    }

    @Test
    void revoke_stampsALiveLink_andRefusesOneThatIsSpentOrNotYours() {
        TrainerInviteLink live = aLink("t1");
        when(linkRepository.findByIdAndTrainerId(5L, TRAINER_ID)).thenReturn(Optional.of(live));
        service.revoke(5L);
        assertThat(live.getRevokedAt()).isNotNull();

        TrainerInviteLink used = aLink("t2");
        used.setRedeemedAt(Instant.now());
        when(linkRepository.findByIdAndTrainerId(6L, TRAINER_ID)).thenReturn(Optional.of(used));
        assertThatThrownBy(() -> service.revoke(6L)).isInstanceOf(InviteNotFoundException.class);

        when(linkRepository.findByIdAndTrainerId(7L, TRAINER_ID)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.revoke(7L)).isInstanceOf(InviteNotFoundException.class);
    }

    // ---- preview ----

    @Test
    void preview_namesTheTrainer() {
        liveLink("tok");

        assertThat(service.preview("tok").trainerName()).isEqualTo("Kata Coach");
    }

    @Test
    void preview_andRedeem_treatEveryDeadLinkTheSame() {
        TrainerInviteLink expired = liveLink("expired");
        expired.setExpiresAt(Instant.now().minusSeconds(1));
        TrainerInviteLink revoked = liveLink("revoked");
        revoked.setRevokedAt(Instant.now());
        TrainerInviteLink used = liveLink("used");
        used.setRedeemedAt(Instant.now());
        when(linkRepository.findByTokenHash(TokenHasher.hash("unknown"))).thenReturn(Optional.empty());

        for (String token : new String[] {"expired", "revoked", "used", "unknown"}) {
            assertThatThrownBy(() -> service.preview(token)).isInstanceOf(InviteNotFoundException.class);
            assertThatThrownBy(() -> service.redeem(token)).isInstanceOf(InviteNotFoundException.class);
        }
        verify(trainerClientRepository, never()).save(any());
    }

    // ---- redeem ----

    @Test
    void redeem_makesTheUserAnActiveClientAndSpendsTheLink() {
        TrainerInviteLink link = liveLink("tok");
        when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        when(userRepository.getReferenceById(USER_ID)).thenReturn(userWithId(USER_ID));
        when(trainerClientRepository.findFirstByTrainerIdAndClientIdOrderByCreatedAtDesc(TRAINER_ID, USER_ID))
                .thenReturn(Optional.empty());

        service.redeem("tok");

        ArgumentCaptor<TrainerClient> captor = ArgumentCaptor.forClass(TrainerClient.class);
        verify(trainerClientRepository).save(captor.capture());
        TrainerClient relationship = captor.getValue();
        assertThat(relationship.getStatus()).isEqualTo(TrainerClientStatus.ACTIVE);
        assertThat(relationship.getTrainer()).isSameAs(trainer);
        assertThat(relationship.getClient().getId()).isEqualTo(USER_ID);
        assertThat(relationship.getRespondedAt()).isNotNull();
        assertThat(link.getRedeemedAt()).isNotNull();
        assertThat(link.getRedeemedBy()).isEqualTo(USER_ID);
        verify(seatLimitService).assertCanAcquireClientForAccept(TRAINER_ID);
    }

    @Test
    void redeem_answersAnEmailInviteThatIsWaitingForThisUserInsteadOfAddingASecondLiveRow() {
        liveLink("tok");
        when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        TrainerClient waiting = new TrainerClient();
        waiting.setId(30L);
        waiting.setStatus(TrainerClientStatus.PENDING);
        waiting.setTrainer(trainer);
        waiting.setClient(userWithId(USER_ID));
        waiting.setCreatedAt(Instant.now().minusSeconds(3600));
        waiting.setExpiresAt(Instant.now().plusSeconds(3600));
        when(trainerClientRepository.findFirstByTrainerIdAndClientIdOrderByCreatedAtDesc(TRAINER_ID, USER_ID))
                .thenReturn(Optional.of(waiting));

        service.redeem("tok");

        verify(trainerClientRepository).save(waiting);
        assertThat(waiting.getId()).isEqualTo(30L);
        assertThat(waiting.getStatus()).isEqualTo(TrainerClientStatus.ACTIVE);
        assertThat(waiting.getRespondedAt()).isNotNull();
    }

    @Test
    void redeem_aPastRelationshipThatEndedDoesNotBlockJoiningAgain() {
        liveLink("tok");
        when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        when(userRepository.getReferenceById(USER_ID)).thenReturn(userWithId(USER_ID));
        TrainerClient ended = new TrainerClient();
        ended.setId(31L);
        ended.setStatus(TrainerClientStatus.REVOKED);
        when(trainerClientRepository.findFirstByTrainerIdAndClientIdOrderByCreatedAtDesc(TRAINER_ID, USER_ID))
                .thenReturn(Optional.of(ended));

        service.redeem("tok");

        ArgumentCaptor<TrainerClient> captor = ArgumentCaptor.forClass(TrainerClient.class);
        verify(trainerClientRepository).save(captor.capture());
        assertThat(captor.getValue()).isNotSameAs(ended);
        assertThat(ended.getStatus()).isEqualTo(TrainerClientStatus.REVOKED);
    }

    @Test
    void redeem_yourOwnLinkIsRefused() {
        TrainerInviteLink link = liveLink("tok");

        assertThatThrownBy(() -> service.redeem("tok")).isInstanceOf(SelfInviteException.class);

        assertThat(link.getRedeemedAt()).isNull();
        verify(trainerClientRepository, never()).save(any());
    }

    @Test
    void redeem_anExistingClientIsRefusedAndTheLinkIsNotSpent() {
        TrainerInviteLink link = liveLink("tok");
        when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        when(trainerClientRepository.existsByTrainerIdAndClientIdAndStatus(TRAINER_ID, USER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(true);

        assertThatThrownBy(() -> service.redeem("tok")).isInstanceOf(AlreadyClientException.class);

        assertThat(link.getRedeemedAt()).isNull();
    }

    @Test
    void redeem_withNoFreeSeatFailsAndTheLinkIsNotSpent() {
        TrainerInviteLink link = liveLink("tok");
        when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        doThrow(new SeatLimitExceededException("full")).when(seatLimitService).assertCanAcquireClientForAccept(TRAINER_ID);

        assertThatThrownBy(() -> service.redeem("tok")).isInstanceOf(SeatLimitExceededException.class);

        assertThat(link.getRedeemedAt()).isNull();
        verify(trainerClientRepository, never()).save(any());
    }

    private static User userWithId(Long id) {
        User u = new User();
        u.setId(id);
        return u;
    }
}
