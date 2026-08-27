package com.lifey.billing.repository;

import com.lifey.billing.entity.AiUsageCounter;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.annotation.Transactional;
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
 * Repository slice for {@link AiUsageCounter} — the round trip, the
 * `(user_id, year_month)` unique constraint from V76
 * (docs/landing_page/64-billing-backend-plan.md §8), and {@code
 * incrementUsage}'s upsert, both the insert and the conflict-update branch.
 */
@SpringBootTest
@Testcontainers
class AiUsageCounterRepositoryTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    AiUsageCounterRepository repository;

    @Test
    void savesAndReadsBackACounter() {
        Long userId = saveUser("ai-usage-" + System.nanoTime() + "@example.com").getId();
        AiUsageCounter counter = newCounter(userId, "2026-08", 2);

        repository.save(counter);

        Optional<AiUsageCounter> reloaded = repository.findByUserIdAndYearMonth(userId, "2026-08");
        assertThat(reloaded).isPresent();
        assertThat(reloaded.get().getUsedCount()).isEqualTo(2);
    }

    @Test
    void findByUserIdAndYearMonth_noRowYet_isEmpty() {
        Long userId = saveUser("ai-usage-none-" + System.nanoTime() + "@example.com").getId();

        assertThat(repository.findByUserIdAndYearMonth(userId, "2026-08")).isEmpty();
    }

    @Test
    void rejectsASecondRowForTheSameUserAndYearMonth() {
        Long userId = saveUser("ai-usage-dup-" + System.nanoTime() + "@example.com").getId();
        repository.save(newCounter(userId, "2026-08", 1));

        assertThatThrownBy(() -> repository.save(newCounter(userId, "2026-08", 1)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void allowsTheSameUserAcrossDifferentMonths() {
        Long userId = saveUser("ai-usage-multi-month-" + System.nanoTime() + "@example.com").getId();
        repository.save(newCounter(userId, "2026-07", 3));
        repository.save(newCounter(userId, "2026-08", 1));

        assertThat(repository.findByUserIdAndYearMonth(userId, "2026-07").orElseThrow().getUsedCount()).isEqualTo(3);
        assertThat(repository.findByUserIdAndYearMonth(userId, "2026-08").orElseThrow().getUsedCount()).isEqualTo(1);
    }

    /** {@code @Modifying} native queries require an active transaction — {@code AiUsageCounterServiceImpl} provides one in production; this test provides its own. */
    @Test
    @Transactional
    void incrementUsage_noExistingRow_insertsWithCountOne() {
        Long userId = saveUser("ai-usage-insert-" + System.nanoTime() + "@example.com").getId();

        repository.incrementUsage(userId, "2026-08");

        assertThat(repository.findByUserIdAndYearMonth(userId, "2026-08").orElseThrow().getUsedCount()).isEqualTo(1);
    }

    @Test
    @Transactional
    void incrementUsage_existingRow_incrementsInPlace() {
        Long userId = saveUser("ai-usage-conflict-" + System.nanoTime() + "@example.com").getId();
        repository.save(newCounter(userId, "2026-08", 4));

        repository.incrementUsage(userId, "2026-08");
        repository.incrementUsage(userId, "2026-08");

        assertThat(repository.findByUserIdAndYearMonth(userId, "2026-08").orElseThrow().getUsedCount()).isEqualTo(6);
    }

    private AiUsageCounter newCounter(Long userId, String yearMonth, int usedCount) {
        AiUsageCounter counter = new AiUsageCounter();
        counter.setUser(userRepository.getReferenceById(userId));
        counter.setYearMonth(yearMonth);
        counter.setUsedCount(usedCount);
        return counter;
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
