package com.lifey.billing;

import com.lifey.auth.service.JwtService;
import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.entity.TrainerPlan;
import com.lifey.billing.repository.SubscriptionRepository;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The Prompt 6 *Verify* line in docs/landing_page/64-billing-backend-plan.md:
 * "integration tests for send-over-limit, accept-over-limit, the concurrent
 * accept race, and — importantly — that chat and every read path still work
 * at CANCELED." (Chat lives in the separate {@code lifey-chat} service and
 * has no dependency on this billing package at all — see backend/CLAUDE.md —
 * so there is nothing to exercise for it here; verified by that absence,
 * not by a test.) Real JWTs, real DB, real security filter chain.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@TestPropertySource(properties = "lifey.billing.enabled=true")
class SeatEnforcementIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    JwtService jwtService;

    @Autowired
    UserRepository userRepository;

    @Autowired
    SubscriptionRepository subscriptionRepository;

    @Autowired
    TrainerClientRepository trainerClientRepository;

    @Test
    void sendInvite_overLimit_isRejectedWith409() throws Exception {
        User trainer = saveTrainer();
        givenSubscription(trainer, SubscriptionStatus.ACTIVE, TrainerPlan.STARTER); // maxClients = 5
        for (int i = 0; i < 5; i++) {
            saveActiveRelationship(trainer, saveUser("send-over-limit-active-" + i));
        }
        User sixthInvitee = saveUser("send-over-limit-invitee");

        mockMvc.perform(post("/api/v1/trainer/invites")
                        .header("Authorization", "Bearer " + tokenFor(trainer))
                        .contentType("application/json")
                        .content("{\"email\":\"" + sixthInvitee.getEmail() + "\"}"))
                .andExpect(status().isConflict());
    }

    @Test
    void sendInvite_underLimit_stillSucceeds() throws Exception {
        User trainer = saveTrainer();
        givenSubscription(trainer, SubscriptionStatus.ACTIVE, TrainerPlan.STARTER);
        for (int i = 0; i < 3; i++) {
            saveActiveRelationship(trainer, saveUser("send-under-limit-active-" + i));
        }
        User invitee = saveUser("send-under-limit-invitee");

        mockMvc.perform(post("/api/v1/trainer/invites")
                        .header("Authorization", "Bearer " + tokenFor(trainer))
                        .contentType("application/json")
                        .content("{\"email\":\"" + invitee.getEmail() + "\"}"))
                .andExpect(status().isCreated());
    }

    @Test
    void acceptInvite_overLimit_isRejectedWith409() throws Exception {
        User trainer = saveTrainer();
        givenSubscription(trainer, SubscriptionStatus.ACTIVE, TrainerPlan.STARTER);
        for (int i = 0; i < 5; i++) {
            saveActiveRelationship(trainer, saveUser("accept-over-limit-active-" + i));
        }
        // Queued while the trainer still had room, or while billing was disabled —
        // either way, the accept-time re-check must still catch it (64 §4.3).
        User client = saveUser("accept-over-limit-client");
        TrainerClient pending = savePendingRelationship(trainer, client);

        mockMvc.perform(post("/api/v1/trainer-invites/" + pending.getId() + "/respond")
                        .header("Authorization", "Bearer " + tokenFor(client))
                        .contentType("application/json")
                        .content("{\"accept\":true}"))
                .andExpect(status().isConflict());

        assertThat(trainerClientRepository.findById(pending.getId()).orElseThrow().getStatus())
                .isEqualTo(TrainerClientStatus.PENDING);
    }

    @Test
    void acceptInvite_declineIsNeverBlockedByTheSeatLimit() throws Exception {
        User trainer = saveTrainer();
        givenSubscription(trainer, SubscriptionStatus.ACTIVE, TrainerPlan.STARTER);
        for (int i = 0; i < 5; i++) {
            saveActiveRelationship(trainer, saveUser("decline-over-limit-active-" + i));
        }
        User client = saveUser("decline-over-limit-client");
        TrainerClient pending = savePendingRelationship(trainer, client);

        mockMvc.perform(post("/api/v1/trainer-invites/" + pending.getId() + "/respond")
                        .header("Authorization", "Bearer " + tokenFor(client))
                        .contentType("application/json")
                        .content("{\"accept\":false}"))
                .andExpect(status().isNoContent());
    }

    @Test
    void concurrentAccept_forTheLastSeat_onlyOneWins() throws Exception {
        User trainer = saveTrainer();
        givenSubscription(trainer, SubscriptionStatus.ACTIVE, TrainerPlan.STARTER); // maxClients = 5
        for (int i = 0; i < 4; i++) {
            saveActiveRelationship(trainer, saveUser("race-active-" + i));
        }
        User clientA = saveUser("race-client-a");
        User clientB = saveUser("race-client-b");
        TrainerClient inviteA = savePendingRelationship(trainer, clientA);
        TrainerClient inviteB = savePendingRelationship(trainer, clientB);

        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch go = new CountDownLatch(1);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        try {
            Future<MvcResult> resultA = executor.submit(() -> acceptRacingly(inviteA, clientA, ready, go));
            Future<MvcResult> resultB = executor.submit(() -> acceptRacingly(inviteB, clientB, ready, go));

            ready.await(5, TimeUnit.SECONDS);
            go.countDown();

            int statusA = resultA.get(10, TimeUnit.SECONDS).getResponse().getStatus();
            int statusB = resultB.get(10, TimeUnit.SECONDS).getResponse().getStatus();

            List<Integer> statuses = List.of(statusA, statusB);
            assertThat(statuses).containsExactlyInAnyOrder(204, 409);
        } finally {
            executor.shutdownNow();
        }

        assertThat(trainerClientRepository.countByTrainerIdAndStatus(trainer.getId(), TrainerClientStatus.ACTIVE)).isEqualTo(5);
    }

    private MvcResult acceptRacingly(TrainerClient invite, User client, CountDownLatch ready, CountDownLatch go) throws Exception {
        ready.countDown();
        go.await();
        return mockMvc.perform(post("/api/v1/trainer-invites/" + invite.getId() + "/respond")
                        .header("Authorization", "Bearer " + tokenFor(client))
                        .contentType("application/json")
                        .content("{\"accept\":true}"))
                .andReturn();
    }

    @Test
    void readEndpoints_stillWorkWhenCanceled() throws Exception {
        User trainer = saveTrainer();
        givenSubscription(trainer, SubscriptionStatus.CANCELED, TrainerPlan.STARTER);
        saveActiveRelationship(trainer, saveUser("canceled-read-active"));

        mockMvc.perform(get("/api/v1/trainer/clients").header("Authorization", "Bearer " + tokenFor(trainer)))
                .andExpect(status().isOk());
    }

    @Test
    void revokeClient_stillWorksWhenCanceled() throws Exception {
        // Managing an existing relationship (not acquiring a new one) is never blocked (64 §4.3).
        User trainer = saveTrainer();
        givenSubscription(trainer, SubscriptionStatus.CANCELED, TrainerPlan.STARTER);
        User client = saveUser("canceled-revoke-client");
        saveActiveRelationship(trainer, client);

        mockMvc.perform(delete("/api/v1/trainer/clients/" + client.getId())
                        .header("Authorization", "Bearer " + tokenFor(trainer)))
                .andExpect(status().isNoContent());
    }

    @Test
    void sendInvite_isRejectedWhenCanceled() throws Exception {
        User trainer = saveTrainer();
        givenSubscription(trainer, SubscriptionStatus.CANCELED, TrainerPlan.STARTER);
        User invitee = saveUser("canceled-send-invitee");

        mockMvc.perform(post("/api/v1/trainer/invites")
                        .header("Authorization", "Bearer " + tokenFor(trainer))
                        .contentType("application/json")
                        .content("{\"email\":\"" + invitee.getEmail() + "\"}"))
                .andExpect(status().isConflict());
    }

    private void givenSubscription(User trainer, SubscriptionStatus status, TrainerPlan plan) {
        Subscription subscription = new Subscription();
        subscription.setUser(trainer);
        subscription.setProvider(SubscriptionProvider.STRIPE);
        subscription.setStatus(status);
        subscription.setPlan(plan);
        subscriptionRepository.save(subscription);
    }

    private void saveActiveRelationship(User trainer, User client) {
        TrainerClient relationship = new TrainerClient();
        relationship.setTrainer(trainer);
        relationship.setClient(client);
        relationship.setStatus(TrainerClientStatus.ACTIVE);
        relationship.setCreatedAt(Instant.now());
        relationship.setExpiresAt(Instant.now().plusSeconds(3600));
        relationship.setRespondedAt(Instant.now());
        trainerClientRepository.save(relationship);
    }

    private TrainerClient savePendingRelationship(User trainer, User client) {
        TrainerClient relationship = new TrainerClient();
        relationship.setTrainer(trainer);
        relationship.setClient(client);
        relationship.setStatus(TrainerClientStatus.PENDING);
        relationship.setCreatedAt(Instant.now());
        relationship.setExpiresAt(Instant.now().plusSeconds(3600));
        return trainerClientRepository.save(relationship);
    }

    private User saveTrainer() {
        return saveUser("trainer", Role.ROLE_USER, Role.ROLE_TRAINER);
    }

    private User saveUser(String slug) {
        return saveUser(slug, Role.ROLE_USER);
    }

    private User saveUser(String slug, Role... roles) {
        User user = new User();
        user.setEmail("seat-enforcement-" + slug + "-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(roles)));
        return userRepository.save(user);
    }

    private String tokenFor(User user) {
        return jwtService.generateAccessToken(user);
    }
}
