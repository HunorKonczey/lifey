package com.lifey.auth.repository;

import jakarta.persistence.LockModeType;
import org.junit.jupiter.api.Test;
import org.springframework.data.jpa.repository.Lock;

import java.lang.reflect.Method;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The wrong-code counter of a password reset is read, compared and written back; only a lock on the token row
 * makes the five-attempt lockout hold against parallel guesses. Pinned here because nothing but a concurrent
 * test against Postgres would notice it going missing.
 */
class PasswordResetTokenRepositoryLockTest {

    @Test
    void theTokenTheResetChecksIsLockedForWriting() throws Exception {
        Method finder = PasswordResetTokenRepository.class
                .getMethod("findFirstByUserIdAndUsedAtIsNullOrderByCreatedAtDesc", Long.class);

        Lock lock = finder.getAnnotation(Lock.class);

        assertThat(lock).isNotNull();
        assertThat(lock.value()).isEqualTo(LockModeType.PESSIMISTIC_WRITE);
    }
}
