package com.lifey.trainer;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.weight.dto.WeightRequest;
import com.lifey.weight.service.WeightService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * The weigh-in push through the real wiring (LIF-100): {@code WeightService.create} publishes the event, the listener runs
 * after the commit, counts the week in the database and tells the active trainer - once for the first weigh-in of the week,
 * not for the second, and never for a pending relationship.
 */
@SpringBootTest
@Testcontainers
class ClientWeighInPushIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    WeightService weightService;

    @Autowired
    UserRepository userRepository;

    @Autowired
    TrainerClientRepository trainerClientRepository;

    @MockitoBean
    CurrentUserProvider currentUserProvider;

    @MockitoBean
    PushService pushService;

    private User trainer;
    private User client;

    @BeforeEach
    void seed() {
        trainer = saveUser("weighin-trainer");
        client = saveUser("weighin-client");
        client.setFirstName("Anna");
        userRepository.save(client);
        when(currentUserProvider.getUserId()).thenReturn(client.getId());
    }

    @Test
    void theFirstWeighInOfTheWeekTellsTheActiveTrainer_theSecondDoesNot() {
        relationship(TrainerClientStatus.ACTIVE);
        LocalDate today = LocalDate.now(ZoneOffset.UTC);

        weightService.create(new WeightRequest(today, 82.4));
        weightService.create(new WeightRequest(today, 82.1));

        ArgumentCaptor<PushMessage> message = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService, org.mockito.Mockito.times(1)).sendToUser(eq(trainer.getId()), message.capture());
        assertThat(message.getValue().body()).isEqualTo("Anna logged this week's weigh-in: 82.4 kg");
    }

    @Test
    void aPendingInviteIsNotATrainerYet() {
        relationship(TrainerClientStatus.PENDING);

        weightService.create(new WeightRequest(LocalDate.now(ZoneOffset.UTC), 82.4));

        verify(pushService, never()).sendToUser(any(), any());
    }

    private void relationship(TrainerClientStatus status) {
        TrainerClient tc = new TrainerClient();
        tc.setTrainer(trainer);
        tc.setClient(client);
        tc.setStatus(status);
        tc.setCreatedAt(Instant.now());
        tc.setExpiresAt(Instant.now().plusSeconds(3600));
        trainerClientRepository.save(tc);
    }

    private User saveUser(String prefix) {
        User user = new User();
        user.setEmail(prefix + "-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(user);
    }
}
