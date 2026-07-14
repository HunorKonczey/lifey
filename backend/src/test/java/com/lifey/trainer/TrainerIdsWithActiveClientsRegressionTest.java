package com.lifey.trainer;

import com.lifey.trainer.entity.TrainerClient;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Regression test for {@link TrainerClientRepository#findTrainerIdsWithActiveClients()} —
 * the weekly trainer report job's (docs/33-weekly-trainer-report-plan.md) fan-out
 * list. Must exclude PENDING/REVOKED/EXPIRED relationships and never duplicate a
 * trainer with more than one active client.
 */
@SpringBootTest
@Testcontainers
class TrainerIdsWithActiveClientsRegressionTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    TrainerClientRepository trainerClientRepository;

    Long activeTrainerId;
    Long pendingOnlyTrainerId;
    Long revokedOnlyTrainerId;

    @BeforeEach
    void seedTrainerClientRelationships() {
        activeTrainerId = saveUser("weekly-report-active-trainer-" + System.nanoTime() + "@example.com").getId();
        pendingOnlyTrainerId = saveUser("weekly-report-pending-trainer-" + System.nanoTime() + "@example.com").getId();
        revokedOnlyTrainerId = saveUser("weekly-report-revoked-trainer-" + System.nanoTime() + "@example.com").getId();

        User clientA = saveUser("weekly-report-client-a-" + System.nanoTime() + "@example.com");
        User clientB = saveUser("weekly-report-client-b-" + System.nanoTime() + "@example.com");

        // Two active clients under the same trainer — must appear only once.
        saveRelationship(activeTrainerId, clientA, TrainerClientStatus.ACTIVE);
        saveRelationship(activeTrainerId, clientB, TrainerClientStatus.ACTIVE);

        saveRelationship(pendingOnlyTrainerId, clientA, TrainerClientStatus.PENDING);
        saveRelationship(revokedOnlyTrainerId, clientA, TrainerClientStatus.REVOKED);
    }

    @Test
    void returnsOnlyTrainersWithAtLeastOneActiveClient_deduplicated() {
        List<Long> trainerIds = trainerClientRepository.findTrainerIdsWithActiveClients();

        assertThat(trainerIds).containsExactlyInAnyOrder(activeTrainerId)
                .doesNotContain(pendingOnlyTrainerId, revokedOnlyTrainerId);
    }

    private User saveUser(String email) {
        User user = new User();
        user.setEmail(email);
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(user);
    }

    private void saveRelationship(Long trainerId, User client, TrainerClientStatus status) {
        TrainerClient tc = new TrainerClient();
        tc.setTrainer(userRepository.getReferenceById(trainerId));
        tc.setClient(client);
        tc.setStatus(status);
        tc.setCreatedAt(Instant.now());
        tc.setExpiresAt(Instant.now().plusSeconds(3600));
        trainerClientRepository.save(tc);
    }
}
