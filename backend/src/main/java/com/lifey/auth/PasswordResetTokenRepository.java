package com.lifey.auth;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, UUID> {

    Optional<PasswordResetToken> findFirstByUserIdAndUsedAtIsNullOrderByCreatedAtDesc(Long userId);

    long countByUserIdAndCreatedAtAfter(Long userId, Instant since);

    @Modifying
    void deleteByUserIdAndUsedAtIsNull(Long userId);

    @Modifying
    @Query("delete from PasswordResetToken t where (t.usedAt is not null and t.usedAt < :cutoff) or t.expiresAt < :cutoff")
    void deleteStaleTokens(@Param("cutoff") Instant cutoff);
}
