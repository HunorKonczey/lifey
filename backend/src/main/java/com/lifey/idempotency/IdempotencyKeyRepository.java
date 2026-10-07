package com.lifey.idempotency;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;

public interface IdempotencyKeyRepository extends JpaRepository<IdempotencyKey, Long> {

    Optional<IdempotencyKey> findByUserIdAndIdemKey(Long userId, String idemKey);

    /** 1 if this call claimed the key, 0 if the user already had a row for it. */
    @Modifying
    @Query(value = """
            insert into idempotency_keys (user_id, idem_key, method, path, created_at)
            values (:userId, :idemKey, :method, :path, :now)
            on conflict (user_id, idem_key) do nothing
            """, nativeQuery = true)
    int claim(@Param("userId") Long userId, @Param("idemKey") String idemKey, @Param("method") String method,
              @Param("path") String path, @Param("now") Instant now);

    /** Re-claims a request that never answered and has been silent since before {@code cutoff}. */
    @Modifying
    @Query("""
            update IdempotencyKey k set k.createdAt = :now
            where k.user.id = :userId and k.idemKey = :idemKey and k.responseStatus is null and k.createdAt < :cutoff
            """)
    int takeOverAbandoned(@Param("userId") Long userId, @Param("idemKey") String idemKey,
                          @Param("cutoff") Instant cutoff, @Param("now") Instant now);

    @Modifying
    @Query("""
            update IdempotencyKey k set k.responseStatus = :status, k.responseContentType = :contentType,
                   k.responseBody = :body
            where k.user.id = :userId and k.idemKey = :idemKey
            """)
    int complete(@Param("userId") Long userId, @Param("idemKey") String idemKey, @Param("status") int status,
                 @Param("contentType") String contentType, @Param("body") byte[] body);

    /** Frees a key whose request did not succeed, so the client's retry runs it again. */
    @Modifying
    @Query("delete from IdempotencyKey k where k.user.id = :userId and k.idemKey = :idemKey and k.responseStatus is null")
    int release(@Param("userId") Long userId, @Param("idemKey") String idemKey);

    @Modifying
    @Query("delete from IdempotencyKey k where k.createdAt < :cutoff")
    int deleteOlderThan(@Param("cutoff") Instant cutoff);
}
