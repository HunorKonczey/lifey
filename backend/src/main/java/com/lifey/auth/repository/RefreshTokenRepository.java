package com.lifey.auth.repository;

import com.lifey.auth.entity.RefreshToken;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    List<RefreshToken> findAllByUserIdAndRevokedFalse(Long userId);

    /** Super-admin stats: distinct accounts that signed in or refreshed a session since `since`. */
    @Query("select count(distinct rt.user.id) from RefreshToken rt where rt.createdAt > :since")
    long countDistinctUsersSince(@Param("since") Instant since);
}
