package com.lifey.sleep;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface SleepSessionRepository extends JpaRepository<SleepSession, Long> {

    List<SleepSession> findAllByUserIdAndDeletedAtIsNullOrderByEndedAtDesc(Long userId);

    Optional<SleepSession> findByIdAndUserId(Long id, Long userId);

    /**
     * Whether the user already has a session for this store record, soft-deleted ones included: the import dedupe
     * key ({@code sleep_sessions_user_id_health_record_id_unique}, V98). A night the user deleted must not come back
     * on the next import.
     */
    boolean existsByUserIdAndHealthRecordId(Long userId, String healthRecordId);

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md). Deliberately not filtered on deletedAt: the tombstones are how
     * the mobile client learns to remove its local rows.
     */
    Page<SleepSession> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);
}
