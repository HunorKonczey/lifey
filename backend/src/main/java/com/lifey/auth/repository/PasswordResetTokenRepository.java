package com.lifey.auth.repository;

import com.lifey.auth.entity.PasswordResetToken;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, UUID> {

    /**
     * Locked for the whole reset attempt. The wrong-code counter is read, compared and then written back, so
     * without the lock a burst of parallel guesses all read {@code attempts = 0} and every one of them gets
     * checked: the five-attempt lockout became "five per round trip", and a six-digit code is only a million
     * guesses wide. With the lock the attempts queue up and each sees the count the one before it saved.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<PasswordResetToken> findFirstByUserIdAndUsedAtIsNullOrderByCreatedAtDesc(Long userId);

    long countByUserIdAndCreatedAtAfter(Long userId, Instant since);

    @Modifying
    void deleteByUserIdAndUsedAtIsNull(Long userId);

    @Modifying
    @Query("delete from PasswordResetToken t where (t.usedAt is not null and t.usedAt < :cutoff) or t.expiresAt < :cutoff")
    void deleteStaleTokens(@Param("cutoff") Instant cutoff);
}
