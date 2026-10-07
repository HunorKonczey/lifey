package com.lifey.auth.repository;

import com.lifey.auth.TokenHasher;
import com.lifey.auth.entity.PasswordResetToken;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * The wrong-code counter of a password reset is read, compared and written back, so a second guess must not
 * even <em>read</em> the token until the first one's transaction is over — otherwise parallel guesses all see
 * "0 attempts" and the five-attempt lockout never closes. Checked deterministically, against a real Postgres:
 * while one transaction holds the token, another transaction asking for it has to wait.
 */
@SpringBootTest
@Testcontainers
class PasswordResetTokenLockingTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    PasswordResetTokenRepository tokenRepository;

    @Autowired
    UserRepository userRepository;

    @Autowired
    PlatformTransactionManager transactionManager;

    @Test
    void aSecondTransactionWaitsForTheFirstOneToFinishWithTheToken() throws Exception {
        User user = new User();
        user.setEmail("reset-lock-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        Long userId = userRepository.save(user).getId();

        PasswordResetToken token = new PasswordResetToken();
        token.setUser(user);
        token.setCodeHash(TokenHasher.hash("123456"));
        token.setExpiresAt(Instant.now().plusSeconds(600));
        token.setCreatedAt(Instant.now());
        tokenRepository.save(token);

        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        CompletableFuture<Integer> second;
        try {
            second = tx.execute(first -> {
                assertThat(tokenRepository.findFirstByUserIdAndUsedAtIsNullOrderByCreatedAtDesc(userId)).isPresent();

                // While this transaction still holds the token, another one asks for it.
                CompletableFuture<Integer> other = CompletableFuture.supplyAsync(() -> new TransactionTemplate(transactionManager)
                        .execute(inner -> tokenRepository.findFirstByUserIdAndUsedAtIsNullOrderByCreatedAtDesc(userId)
                                .orElseThrow().getAttempts()));

                assertThatThrownBy(() -> other.get(1, TimeUnit.SECONDS)).isInstanceOf(TimeoutException.class);
                return other;
            });
        } finally {
            // the first transaction is committed here, which is what releases the second
        }

        assertThat(second.get(10, TimeUnit.SECONDS)).isEqualTo(0);
    }
}
