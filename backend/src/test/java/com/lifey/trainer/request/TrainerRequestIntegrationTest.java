package com.lifey.trainer.request;

import com.lifey.auth.service.JwtService;
import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
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

import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The Prompt 1 *Verify* line in docs/landing_page/66-trainer-billing-web-plan.md:
 * "one open request per user, super-admin list, approval both grants the role
 * and resolves the request, approval starts the trial (64 §4.1)." End to end
 * over the real security chain and DB — matches {@code TrainerTrialIntegrationTest}'s
 * pattern, extended one hop further back to the request itself.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class TrainerRequestIntegrationTest {

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
    TrainerRequestRepository trainerRequestRepository;

    @Autowired
    SubscriptionRepository subscriptionRepository;

    @Test
    void submittingASecondRequestWhileOneIsOpen_isRejected() throws Exception {
        User applicant = saveUser("second-request", Role.ROLE_USER);

        mockMvc.perform(post("/api/v1/trainer-requests")
                        .header("Authorization", "Bearer " + tokenFor(applicant))
                        .contentType("application/json")
                        .content("{\"motivation\":\"I coach people\",\"clientCount\":5}"))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/trainer-requests")
                        .header("Authorization", "Bearer " + tokenFor(applicant))
                        .contentType("application/json")
                        .content("{\"motivation\":\"still me\",\"clientCount\":6}"))
                .andExpect(status().isConflict());
    }

    @Test
    void aPendingRequest_appearsInTheSuperAdminList() throws Exception {
        User superAdmin = saveUser("queue-super-admin", Role.ROLE_SUPER_ADMIN);
        User applicant = saveUser("queue-applicant", Role.ROLE_USER);
        mockMvc.perform(post("/api/v1/trainer-requests")
                        .header("Authorization", "Bearer " + tokenFor(applicant))
                        .contentType("application/json")
                        .content("{\"motivation\":\"queue test\",\"clientCount\":3}"))
                .andExpect(status().isCreated());

        mockMvc.perform(get("/api/v1/superadmin/trainer-requests")
                        .header("Authorization", "Bearer " + tokenFor(superAdmin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[?(@.userId == " + applicant.getId() + ")]").exists());
    }

    @Test
    void approving_grantsTheRole_resolvesTheRequest_andStartsTheTrial() throws Exception {
        User superAdmin = saveUser("approve-super-admin", Role.ROLE_SUPER_ADMIN);
        User applicant = saveUser("approve-applicant", Role.ROLE_USER);
        mockMvc.perform(post("/api/v1/trainer-requests")
                        .header("Authorization", "Bearer " + tokenFor(applicant))
                        .contentType("application/json")
                        .content("{\"motivation\":\"approve me\",\"clientCount\":4}"))
                .andExpect(status().isCreated());
        Long requestId = trainerRequestRepository.findFirstByUserIdOrderByCreatedAtDesc(applicant.getId())
                .orElseThrow().getId();

        mockMvc.perform(post("/api/v1/superadmin/trainer-requests/" + requestId + "/approve")
                        .header("Authorization", "Bearer " + tokenFor(superAdmin)))
                .andExpect(status().isNoContent());

        User reloadedApplicant = userRepository.findById(applicant.getId()).orElseThrow();
        assertThat(reloadedApplicant.getRoles()).contains(Role.ROLE_TRAINER);

        TrainerRequest resolved = trainerRequestRepository.findById(requestId).orElseThrow();
        assertThat(resolved.getStatus()).isEqualTo(TrainerRequestStatus.APPROVED);
        assertThat(resolved.getDecidedAt()).isNotNull();
        assertThat(resolved.getDecidedBy()).isEqualTo(superAdmin.getId());

        Subscription trial = subscriptionRepository.findByUserIdAndProvider(applicant.getId(), SubscriptionProvider.STRIPE)
                .orElseThrow();
        assertThat(trial.getStatus()).isEqualTo(SubscriptionStatus.TRIALING);
    }

    @Test
    void rejecting_marksRejected_withoutGrantingAnyRole() throws Exception {
        User superAdmin = saveUser("reject-super-admin", Role.ROLE_SUPER_ADMIN);
        User applicant = saveUser("reject-applicant", Role.ROLE_USER);
        mockMvc.perform(post("/api/v1/trainer-requests")
                        .header("Authorization", "Bearer " + tokenFor(applicant))
                        .contentType("application/json")
                        .content("{\"motivation\":\"reject me\",\"clientCount\":2}"))
                .andExpect(status().isCreated());
        Long requestId = trainerRequestRepository.findFirstByUserIdOrderByCreatedAtDesc(applicant.getId())
                .orElseThrow().getId();

        mockMvc.perform(post("/api/v1/superadmin/trainer-requests/" + requestId + "/reject")
                        .header("Authorization", "Bearer " + tokenFor(superAdmin)))
                .andExpect(status().isNoContent());

        TrainerRequest resolved = trainerRequestRepository.findById(requestId).orElseThrow();
        assertThat(resolved.getStatus()).isEqualTo(TrainerRequestStatus.REJECTED);
        assertThat(resolved.getDecidedBy()).isEqualTo(superAdmin.getId());
        User reloadedApplicant = userRepository.findById(applicant.getId()).orElseThrow();
        assertThat(reloadedApplicant.getRoles()).doesNotContain(Role.ROLE_TRAINER);

        // A rejected applicant is free to try again — the partial unique index only covers PENDING.
        mockMvc.perform(post("/api/v1/trainer-requests")
                        .header("Authorization", "Bearer " + tokenFor(applicant))
                        .contentType("application/json")
                        .content("{\"motivation\":\"trying again\",\"clientCount\":2}"))
                .andExpect(status().isCreated());
    }

    @Test
    void approvingTheSameRequestTwice_isRejectedWithConflict() throws Exception {
        User superAdmin = saveUser("double-approve-super-admin", Role.ROLE_SUPER_ADMIN);
        User applicant = saveUser("double-approve-applicant", Role.ROLE_USER);
        mockMvc.perform(post("/api/v1/trainer-requests")
                        .header("Authorization", "Bearer " + tokenFor(applicant))
                        .contentType("application/json")
                        .content("{\"motivation\":\"approve twice\",\"clientCount\":1}"))
                .andExpect(status().isCreated());
        Long requestId = trainerRequestRepository.findFirstByUserIdOrderByCreatedAtDesc(applicant.getId())
                .orElseThrow().getId();
        mockMvc.perform(post("/api/v1/superadmin/trainer-requests/" + requestId + "/approve")
                        .header("Authorization", "Bearer " + tokenFor(superAdmin)))
                .andExpect(status().isNoContent());

        mockMvc.perform(post("/api/v1/superadmin/trainer-requests/" + requestId + "/approve")
                        .header("Authorization", "Bearer " + tokenFor(superAdmin)))
                .andExpect(status().isConflict());
    }

    @Test
    void grantingRoleTrainerDirectly_bypassingTheQueue_stillResolvesThePendingRequest() throws Exception {
        // 66 §2: "the super admin's existing grant action also resolves the request" —
        // even when a super admin uses the plain user-management page instead of this queue.
        User superAdmin = saveUser("direct-grant-super-admin", Role.ROLE_SUPER_ADMIN);
        User applicant = saveUser("direct-grant-applicant", Role.ROLE_USER);
        mockMvc.perform(post("/api/v1/trainer-requests")
                        .header("Authorization", "Bearer " + tokenFor(applicant))
                        .contentType("application/json")
                        .content("{\"motivation\":\"direct grant\",\"clientCount\":1}"))
                .andExpect(status().isCreated());
        Long requestId = trainerRequestRepository.findFirstByUserIdOrderByCreatedAtDesc(applicant.getId())
                .orElseThrow().getId();

        mockMvc.perform(post("/api/v1/superadmin/users/" + applicant.getId() + "/roles")
                        .header("Authorization", "Bearer " + tokenFor(superAdmin))
                        .contentType("application/json")
                        .content("{\"role\":\"ROLE_TRAINER\"}"))
                .andExpect(status().isOk());

        TrainerRequest resolved = trainerRequestRepository.findById(requestId).orElseThrow();
        assertThat(resolved.getStatus()).isEqualTo(TrainerRequestStatus.APPROVED);
        assertThat(resolved.getDecidedBy()).isEqualTo(superAdmin.getId());
    }

    private User saveUser(String slug, Role... roles) {
        User user = new User();
        user.setEmail("trainer-request-" + slug + "-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(roles)));
        return userRepository.save(user);
    }

    private String tokenFor(User user) {
        return jwtService.generateAccessToken(user);
    }
}
