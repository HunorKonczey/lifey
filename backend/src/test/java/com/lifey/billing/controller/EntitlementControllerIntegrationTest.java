package com.lifey.billing.controller;

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
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashSet;
import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * End-to-end over the real security filter chain, controller, resolver and
 * schema — the plain-user, trainer and sponsored-client scenarios from
 * docs/landing_page/64-billing-backend-plan.md Prompt 2's *Verify* line.
 * {@code lifey.billing.enabled=false} (the rollback switch, tested for its
 * own "everyone is open" behaviour in {@code EntitlementServiceImplTest})
 * would otherwise mask every branch tested here.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@TestPropertySource(properties = "lifey.billing.enabled=true")
class EntitlementControllerIntegrationTest {

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
    void plainUser_resolvesToFree() throws Exception {
        User user = saveUser(Role.ROLE_USER);

        mockMvc.perform(get("/api/v1/me/entitlements").header("Authorization", "Bearer " + tokenFor(user)))
                .andExpect(status().isOk())
                .andExpect(header().string("Cache-Control", "max-age=60, private"))
                .andExpect(jsonPath("$.tier").value("FREE"))
                .andExpect(jsonPath("$.source").value("NONE"))
                .andExpect(jsonPath("$.adsEnabled").value(true))
                .andExpect(jsonPath("$.historyDays").value(30))
                // Both free-tier numbers are asserted against the *real*
                // `application.yml`, not a fixture: 63 D-M5 promises 30 days and
                // 3 AI calls, the paywall design draws "3/3" (69 §4.3, P13), and
                // the config had drifted to 5 unnoticed until
                // docs/landing_page/72 D-F6. This is the assertion that catches
                // it next time.
                .andExpect(jsonPath("$.aiCreditsRemaining").value(3))
                .andExpect(jsonPath("$.trainer").doesNotExist())
                .andExpect(jsonPath("$.degraded").value(false));
    }

    @Test
    void trainerOnTrial_resolvesToTrainerTrial_withTrainerBlock() throws Exception {
        User trainer = saveUser(Role.ROLE_USER, Role.ROLE_TRAINER);

        Subscription trial = new Subscription();
        trial.setUser(trainer);
        trial.setProvider(SubscriptionProvider.STRIPE);
        trial.setStatus(SubscriptionStatus.TRIALING);
        trial.setPlan(TrainerPlan.PRO);
        trial.setTrialEndsAt(Instant.now().plus(10, ChronoUnit.DAYS));
        subscriptionRepository.save(trial);

        mockMvc.perform(get("/api/v1/me/entitlements").header("Authorization", "Bearer " + tokenFor(trainer)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tier").value("PRO"))
                .andExpect(jsonPath("$.source").value("TRAINER_TRIAL"))
                .andExpect(jsonPath("$.trainer.plan").value("PRO"))
                .andExpect(jsonPath("$.trainer.status").value("TRIALING"))
                .andExpect(jsonPath("$.trainer.maxClients").value(25))
                .andExpect(jsonPath("$.trainer.activeClients").value(0));
    }

    @Test
    void sponsoredClient_resolvesToTrainerSponsored() throws Exception {
        User trainer = saveUser(Role.ROLE_USER, Role.ROLE_TRAINER);
        User client = saveUser(Role.ROLE_USER);

        Subscription trainerSubscription = new Subscription();
        trainerSubscription.setUser(trainer);
        trainerSubscription.setProvider(SubscriptionProvider.STRIPE);
        trainerSubscription.setStatus(SubscriptionStatus.ACTIVE);
        trainerSubscription.setPlan(TrainerPlan.STARTER);
        subscriptionRepository.save(trainerSubscription);

        TrainerClient relationship = new TrainerClient();
        relationship.setTrainer(trainer);
        relationship.setClient(client);
        relationship.setStatus(TrainerClientStatus.ACTIVE);
        relationship.setCreatedAt(Instant.now());
        relationship.setExpiresAt(Instant.now().plus(1, ChronoUnit.DAYS));
        trainerClientRepository.save(relationship);

        mockMvc.perform(get("/api/v1/me/entitlements").header("Authorization", "Bearer " + tokenFor(client)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tier").value("PRO"))
                .andExpect(jsonPath("$.source").value("TRAINER_SPONSORED"))
                .andExpect(jsonPath("$.trainer").doesNotExist());
    }

    private User saveUser(Role... roles) {
        User user = new User();
        user.setEmail("entitlement-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(roles)));
        return userRepository.save(user);
    }

    private String tokenFor(User user) {
        return jwtService.generateAccessToken(user);
    }
}
