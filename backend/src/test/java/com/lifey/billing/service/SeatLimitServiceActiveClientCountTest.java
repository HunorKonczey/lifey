package com.lifey.billing.service;

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
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Walks one {@link TrainerClient} through PENDING → ACTIVE → REVOKED → EXPIRED
 * and asserts {@link SeatLimitService#activeClientCount} at each step — the
 * Prompt 3 *Verify* line in docs/landing_page/64-billing-backend-plan.md, and
 * 63 §8.1's "two queries that disagree" risk: only the ACTIVE step may ever
 * count.
 */
@SpringBootTest
@Testcontainers
class SeatLimitServiceActiveClientCountTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    TrainerClientRepository trainerClientRepository;

    @Autowired
    SeatLimitService seatLimitService;

    @Test
    void activeClientCount_countsOnlyWhileTheRelationshipIsActive() {
        Long trainerId = saveUser("seat-count-trainer-" + System.nanoTime() + "@example.com").getId();
        User client = saveUser("seat-count-client-" + System.nanoTime() + "@example.com");

        TrainerClient relationship = new TrainerClient();
        relationship.setTrainer(userRepository.getReferenceById(trainerId));
        relationship.setClient(client);
        relationship.setStatus(TrainerClientStatus.PENDING);
        relationship.setCreatedAt(Instant.now());
        relationship.setExpiresAt(Instant.now().plusSeconds(3600));
        trainerClientRepository.save(relationship);

        assertThat(seatLimitService.activeClientCount(trainerId)).isZero();

        relationship.setStatus(TrainerClientStatus.ACTIVE);
        relationship.setRespondedAt(Instant.now());
        trainerClientRepository.save(relationship);

        assertThat(seatLimitService.activeClientCount(trainerId)).isEqualTo(1);

        relationship.setStatus(TrainerClientStatus.REVOKED);
        relationship.setRevokedAt(Instant.now());
        relationship.setRevokedBy(trainerId);
        trainerClientRepository.save(relationship);

        assertThat(seatLimitService.activeClientCount(trainerId)).isZero();

        relationship.setStatus(TrainerClientStatus.EXPIRED);
        trainerClientRepository.save(relationship);

        assertThat(seatLimitService.activeClientCount(trainerId)).isZero();
    }

    @Test
    void activeClientCount_isNotThrownOffByOtherTrainersOrStatuses() {
        Long trainerId = saveUser("seat-count-multi-trainer-" + System.nanoTime() + "@example.com").getId();
        Long otherTrainerId = saveUser("seat-count-other-trainer-" + System.nanoTime() + "@example.com").getId();

        User activeClient = saveUser("seat-count-active-" + System.nanoTime() + "@example.com");
        User pendingClient = saveUser("seat-count-pending-" + System.nanoTime() + "@example.com");
        User otherTrainersClient = saveUser("seat-count-others-" + System.nanoTime() + "@example.com");

        saveRelationship(trainerId, activeClient, TrainerClientStatus.ACTIVE);
        saveRelationship(trainerId, pendingClient, TrainerClientStatus.PENDING);
        saveRelationship(otherTrainerId, otherTrainersClient, TrainerClientStatus.ACTIVE);

        assertThat(seatLimitService.activeClientCount(trainerId)).isEqualTo(1);
        assertThat(seatLimitService.activeClientCount(otherTrainerId)).isEqualTo(1);
    }

    private void saveRelationship(Long trainerId, User client, TrainerClientStatus status) {
        TrainerClient relationship = new TrainerClient();
        relationship.setTrainer(userRepository.getReferenceById(trainerId));
        relationship.setClient(client);
        relationship.setStatus(status);
        relationship.setCreatedAt(Instant.now());
        relationship.setExpiresAt(Instant.now().plusSeconds(3600));
        trainerClientRepository.save(relationship);
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
