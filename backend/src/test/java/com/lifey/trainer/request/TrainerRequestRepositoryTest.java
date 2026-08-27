package com.lifey.trainer.request;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Repository slice for {@link TrainerRequest} — the round trip, V77's partial
 * unique index actually enforcing "one open request per user"
 * (docs/landing_page/66-trainer-billing-web-plan.md §2, D-T1), and {@code
 * findByStatus}'s join-fetch.
 */
@SpringBootTest
@Testcontainers
class TrainerRequestRepositoryTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    TrainerRequestRepository repository;

    @Test
    void savesAndReadsBackARequest() {
        Long userId = saveUser("trainer-request-" + System.nanoTime() + "@example.com").getId();

        TrainerRequest request = newRequest(userId, TrainerRequestStatus.PENDING);
        request.setMotivation("I coach 15 people already, on spreadsheets.");
        request.setClientCount(15);
        request.setSignupSource("landing-hero");
        Long savedId = repository.save(request).getId();

        TrainerRequest reloaded = repository.findById(savedId).orElseThrow();
        assertThat(reloaded.getUser().getId()).isEqualTo(userId);
        assertThat(reloaded.getStatus()).isEqualTo(TrainerRequestStatus.PENDING);
        assertThat(reloaded.getMotivation()).isEqualTo("I coach 15 people already, on spreadsheets.");
        assertThat(reloaded.getClientCount()).isEqualTo(15);
        assertThat(reloaded.getSignupSource()).isEqualTo("landing-hero");
        assertThat(reloaded.getCreatedAt()).isNotNull();
        assertThat(reloaded.getDecidedAt()).isNull();
        assertThat(reloaded.getDecidedBy()).isNull();
    }

    @Test
    void rejectsASecondPendingRequestForTheSameUser() {
        Long userId = saveUser("trainer-request-dup-" + System.nanoTime() + "@example.com").getId();
        repository.save(newRequest(userId, TrainerRequestStatus.PENDING));

        assertThatThrownBy(() -> repository.save(newRequest(userId, TrainerRequestStatus.PENDING)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void allowsANewPendingRequestOnceThePreviousOneWasDecided() {
        Long userId = saveUser("trainer-request-redo-" + System.nanoTime() + "@example.com").getId();
        TrainerRequest rejected = newRequest(userId, TrainerRequestStatus.REJECTED);
        rejected.setDecidedAt(Instant.now());
        rejected.setDecidedBy(1L);
        repository.save(rejected);

        // No exception: the partial unique index only covers PENDING rows.
        Long secondId = repository.save(newRequest(userId, TrainerRequestStatus.PENDING)).getId();

        assertThat(repository.findById(secondId)).isPresent();
    }

    @Test
    void existsByUserIdAndStatus_reflectsThePendingRow() {
        Long userId = saveUser("trainer-request-exists-" + System.nanoTime() + "@example.com").getId();

        assertThat(repository.existsByUserIdAndStatus(userId, TrainerRequestStatus.PENDING)).isFalse();

        repository.save(newRequest(userId, TrainerRequestStatus.PENDING));

        assertThat(repository.existsByUserIdAndStatus(userId, TrainerRequestStatus.PENDING)).isTrue();
    }

    @Test
    void findFirstByUserIdOrderByCreatedAtDesc_returnsTheMostRecentRegardlessOfStatus() {
        Long userId = saveUser("trainer-request-recent-" + System.nanoTime() + "@example.com").getId();
        TrainerRequest older = newRequest(userId, TrainerRequestStatus.REJECTED);
        older.setCreatedAt(Instant.now().minusSeconds(3600));
        older.setDecidedAt(Instant.now());
        older.setDecidedBy(1L);
        repository.save(older);
        TrainerRequest newer = newRequest(userId, TrainerRequestStatus.PENDING);
        newer.setCreatedAt(Instant.now());
        Long newerId = repository.save(newer).getId();

        Optional<TrainerRequest> mostRecent = repository.findFirstByUserIdOrderByCreatedAtDesc(userId);

        assertThat(mostRecent).isPresent();
        assertThat(mostRecent.get().getId()).isEqualTo(newerId);
    }

    @Test
    void findFirstByUserIdAndStatus_findsThePendingRowOnly() {
        Long userId = saveUser("trainer-request-pending-lookup-" + System.nanoTime() + "@example.com").getId();
        TrainerRequest decided = newRequest(userId, TrainerRequestStatus.APPROVED);
        decided.setDecidedAt(Instant.now());
        decided.setDecidedBy(1L);
        repository.save(decided);

        assertThat(repository.findFirstByUserIdAndStatus(userId, TrainerRequestStatus.PENDING)).isEmpty();

        TrainerRequest pending = repository.save(newRequest(userId, TrainerRequestStatus.PENDING));

        Optional<TrainerRequest> found = repository.findFirstByUserIdAndStatus(userId, TrainerRequestStatus.PENDING);
        assertThat(found).isPresent();
        assertThat(found.get().getId()).isEqualTo(pending.getId());
    }

    @Test
    void findByStatus_joinFetchesTheUser_andPagesByStatus() {
        // Scoped assertions, not a total-row-count assertion: other test methods in this
        // class share the same Testcontainers database and may leave their own PENDING
        // rows behind, since JUnit doesn't guarantee method execution order.
        Long pendingUserId = saveUser("trainer-request-list-pending-" + System.nanoTime() + "@example.com").getId();
        Long approvedUserId = saveUser("trainer-request-list-approved-" + System.nanoTime() + "@example.com").getId();
        repository.save(newRequest(pendingUserId, TrainerRequestStatus.PENDING));
        TrainerRequest approved = newRequest(approvedUserId, TrainerRequestStatus.APPROVED);
        approved.setDecidedAt(Instant.now());
        approved.setDecidedBy(1L);
        repository.save(approved);

        Page<TrainerRequest> page = repository.findByStatus(TrainerRequestStatus.PENDING, Pageable.unpaged());

        assertThat(page.getContent()).extracting(r -> r.getUser().getId()).contains(pendingUserId).doesNotContain(approvedUserId);
        assertThat(page.getContent()).filteredOn(r -> r.getUser().getId().equals(pendingUserId))
                .singleElement().satisfies(r -> assertThat(r.getStatus()).isEqualTo(TrainerRequestStatus.PENDING));
    }

    private TrainerRequest newRequest(Long userId, TrainerRequestStatus status) {
        TrainerRequest request = new TrainerRequest();
        request.setUser(userRepository.getReferenceById(userId));
        request.setStatus(status);
        request.setCreatedAt(Instant.now());
        return request;
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
