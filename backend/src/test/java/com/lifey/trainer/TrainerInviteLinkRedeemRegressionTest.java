package com.lifey.trainer;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.trainer.dto.CreatedTrainerInviteLinkResponse;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.trainer.exception.InviteNotFoundException;
import com.lifey.trainer.service.TrainerInviteLinkService;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
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
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

/**
 * A trainer's shareable join link (LIF-103) against a real database: V85 creates the table, redeeming creates the
 * ordinary ACTIVE relationship (or promotes the email invite that was waiting, which the one-live-row-per-pair index
 * would otherwise refuse), and a link works exactly once.
 */
@SpringBootTest
@Testcontainers
class TrainerInviteLinkRedeemRegressionTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    TrainerInviteLinkService linkService;

    @Autowired
    UserRepository userRepository;

    @Autowired
    TrainerClientRepository trainerClientRepository;

    @MockitoBean
    CurrentUserProvider currentUserProvider;

    private Long trainerId;
    private Long clientId;

    @BeforeEach
    void seedUsers() {
        trainerId = saveUser("link-trainer-" + System.nanoTime() + "@example.com").getId();
        clientId = saveUser("link-client-" + System.nanoTime() + "@example.com").getId();
    }

    @Test
    void aLinkMadeByTheTrainerMakesTheVisitorAClient_onceOnly() {
        when(currentUserProvider.getUserId()).thenReturn(trainerId);
        CreatedTrainerInviteLinkResponse link = linkService.create();
        assertThat(linkService.findActiveForTrainer()).extracting(l -> l.id()).containsExactly(link.id());

        when(currentUserProvider.getUserId()).thenReturn(clientId);
        assertThat(linkService.preview(link.token()).trainerName()).startsWith("link-trainer-");
        linkService.redeem(link.token());

        assertThat(trainerClientRepository.existsByTrainerIdAndClientIdAndStatus(trainerId, clientId, TrainerClientStatus.ACTIVE)).isTrue();
        assertThatThrownBy(() -> linkService.redeem(link.token())).isInstanceOf(InviteNotFoundException.class);
        assertThatThrownBy(() -> linkService.preview(link.token())).isInstanceOf(InviteNotFoundException.class);

        when(currentUserProvider.getUserId()).thenReturn(trainerId);
        assertThat(linkService.findActiveForTrainer()).isEmpty();
    }

    @Test
    void aWaitingEmailInviteIsPromotedInsteadOfTrippingTheOneLiveRowPerPairIndex() {
        TrainerClient waiting = new TrainerClient();
        waiting.setTrainer(userRepository.getReferenceById(trainerId));
        waiting.setClient(userRepository.getReferenceById(clientId));
        waiting.setStatus(TrainerClientStatus.PENDING);
        waiting.setCreatedAt(Instant.now());
        waiting.setExpiresAt(Instant.now().plusSeconds(3600));
        Long waitingId = trainerClientRepository.save(waiting).getId();

        when(currentUserProvider.getUserId()).thenReturn(trainerId);
        CreatedTrainerInviteLinkResponse link = linkService.create();
        when(currentUserProvider.getUserId()).thenReturn(clientId);
        linkService.redeem(link.token());

        TrainerClient after = trainerClientRepository.findById(waitingId).orElseThrow();
        assertThat(after.getStatus()).isEqualTo(TrainerClientStatus.ACTIVE);
        assertThat(after.getRespondedAt()).isNotNull();
        assertThat(trainerClientRepository.findByTrainerIdAndClientIdAndStatus(trainerId, clientId, TrainerClientStatus.ACTIVE)).isPresent();
    }

    @Test
    void aRevokedLinkNoLongerWorks() {
        when(currentUserProvider.getUserId()).thenReturn(trainerId);
        CreatedTrainerInviteLinkResponse link = linkService.create();
        linkService.revoke(link.id());

        when(currentUserProvider.getUserId()).thenReturn(clientId);
        assertThatThrownBy(() -> linkService.redeem(link.token())).isInstanceOf(InviteNotFoundException.class);
        assertThat(trainerClientRepository.existsByTrainerIdAndClientIdAndStatus(trainerId, clientId, TrainerClientStatus.ACTIVE)).isFalse();
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
