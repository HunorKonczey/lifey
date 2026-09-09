package com.lifey.billing;

import com.lifey.auth.service.JwtService;
import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.entity.TrainerPlan;
import com.lifey.billing.repository.SubscriptionRepository;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The other half of Prompt 7's *Verify* line in
 * docs/landing_page/64-billing-backend-plan.md: "granting the role in a test
 * creates a 14-day trial." End to end over the real security chain and DB —
 * {@code SuperAdminUserController} → {@code RoleManagementServiceImpl} →
 * {@code TrainerRoleGrantedEvent} → {@code TrainerTrialListener} →
 * {@code SubscriptionWriter} — not just the listener in isolation.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class TrainerTrialIntegrationTest {

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

    @Test
    void grantingRoleTrainer_createsA14DayProTrial() throws Exception {
        User superAdmin = saveUser("super-admin", Role.ROLE_SUPER_ADMIN);
        User target = saveUser("future-trainer", Role.ROLE_USER);

        mockMvc.perform(post("/api/v1/superadmin/users/" + target.getId() + "/roles")
                        .header("Authorization", "Bearer " + tokenFor(superAdmin))
                        .contentType("application/json")
                        .content("{\"role\":\"ROLE_TRAINER\"}"))
                .andExpect(status().isOk());

        Subscription trial = subscriptionRepository.findByUserIdAndProvider(target.getId(), SubscriptionProvider.STRIPE)
                .orElseThrow();
        assertThat(trial.getStatus()).isEqualTo(SubscriptionStatus.TRIALING);
        assertThat(trial.getPlan()).isEqualTo(TrainerPlan.PRO);
        assertThat(trial.getTrialEndsAt()).isCloseTo(Instant.now().plus(Duration.ofDays(14)), within(Duration.ofMinutes(1)));
    }

    @Test
    void regrantingAfterRevoke_doesNotResetAnExistingSubscription() throws Exception {
        // History is kept (64 §4.1) — a previously-paying trainer must not be
        // reset back to a fresh trial just because their role was revoked and granted again.
        User superAdmin = saveUser("super-admin-regrant", Role.ROLE_SUPER_ADMIN);
        User target = saveUser("returning-trainer", Role.ROLE_USER);
        Subscription existing = new Subscription();
        existing.setUser(userRepository.getReferenceById(target.getId()));
        existing.setProvider(SubscriptionProvider.STRIPE);
        existing.setStatus(SubscriptionStatus.CANCELED);
        existing.setPlan(TrainerPlan.STARTER);
        subscriptionRepository.save(existing);

        mockMvc.perform(post("/api/v1/superadmin/users/" + target.getId() + "/roles")
                        .header("Authorization", "Bearer " + tokenFor(superAdmin))
                        .contentType("application/json")
                        .content("{\"role\":\"ROLE_TRAINER\"}"))
                .andExpect(status().isOk());

        List<Subscription> rows = subscriptionRepository.findByUserId(target.getId());
        assertThat(rows).hasSize(1);
        assertThat(rows.getFirst().getStatus()).isEqualTo(SubscriptionStatus.CANCELED);
        assertThat(rows.getFirst().getPlan()).isEqualTo(TrainerPlan.STARTER);
    }

    private User saveUser(String slug, Role... roles) {
        User user = new User();
        user.setEmail("trainer-trial-" + slug + "-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(roles)));
        return userRepository.save(user);
    }

    private String tokenFor(User user) {
        return jwtService.generateAccessToken(user);
    }
}
